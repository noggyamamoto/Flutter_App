import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/features/history/presentation/providers/history_provider.dart';

import '../../../configuration/domain/entities/performance_settings.dart';
import '../../../configuration/presentation/providers/configuration_provider.dart';
import '../../../connection/domain/entities/device_event.dart';
import '../../../connection/domain/entities/session_config.dart';
import '../../../connection/domain/entities/simulation_note.dart';
import '../../../connection/presentation/providers/connection_provider.dart';
import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';
import '../../../score/domain/services/performance_evaluator.dart';
import '../../../score/presentation/providers/score_provider.dart';
import '../../../songs/domain/entities/song.dart';

import '../../data/datasources/midi_local_datasource.dart';
import '../../data/datasources/midi_local_datasource_impl.dart';

import '../../data/repositories/midi_repository_impl.dart';

import '../../data/services/audio_synth.dart';
import '../../data/services/performance_audio.dart';

import '../../domain/entities/performance_state.dart';

import '../../domain/repositories/midi_repository.dart';

import '../../domain/services/midi_parser.dart';
import '../../domain/services/performance_timeline.dart';

import '../../domain/usecases/get_midi_file.dart';


// ---------------------------------------------------------
// MIDI DATA SOURCE
// ---------------------------------------------------------

final midiDataSourceProvider =
    Provider<MidiLocalDataSource>((ref) {

  return MidiLocalDataSourceImpl();
});


// ---------------------------------------------------------
// MIDI REPOSITORY
// ---------------------------------------------------------

final midiRepositoryProvider =
    Provider<MidiRepository>((ref) {

  final dataSource =
      ref.watch(
    midiDataSourceProvider,
  );

  return MidiRepositoryImpl(
    dataSource,
  );
});


// ---------------------------------------------------------
// GET MIDI FILE
// ---------------------------------------------------------

final getMidiFileProvider =
    Provider<GetMidiFile>((ref) {

  final repository =
      ref.watch(
    midiRepositoryProvider,
  );

  return GetMidiFile(
    repository,
  );
});


// ---------------------------------------------------------
// MIDI PARSER
// ---------------------------------------------------------

final midiParserProvider =
    Provider<MidiParser>((ref) {

  return MidiParser();
});


// ---------------------------------------------------------
// ÁUDIO (música guia e metrônomo do modo demonstração)
// ---------------------------------------------------------

final performanceAudioProvider =
    Provider<PerformanceAudio>((ref) {

  final audio = PerformanceAudio();

  ref.onDispose(audio.dispose);

  return audio;
});


// ---------------------------------------------------------
// PERFORMANCE NOTIFIER
// ---------------------------------------------------------

class PerformanceNotifier
    extends Notifier<PerformanceState> {

  // Compassos de contagem antes da música (RFA05).
  static const countInBars = 2;

  // Tempo extra após o fim da frase para receber as últimas notas.
  static const phraseGraceMs = 400;

  // Intervalo de atualização da tela.
  static const tickInterval = Duration(milliseconds: 30);

  // Relógio local alinhado ao relógio da sessão do dispositivo.
  final Stopwatch _clock = Stopwatch();
  int? _offsetMs;

  Timer? _ticker;
  StreamSubscription<DeviceEvent>? _events;

  PerformanceTimeline? _timeline;
  PerformanceEvaluator? _evaluator;
  PerformanceSettings _settings = const PerformanceSettings();
  bool _simulated = false;

  // Frases já avaliadas e a próxima a ser avaliada.
  final Set<int> _evaluatedPhrases = {};
  int _nextPhrase = 0;

  // Mudança de andamento agendada (frase -> BPM) e se já foi enviada.
  int? _tempoPhrase;
  int? _tempoBpm;
  bool _tempoSent = false;

  // Áudio da música guia / cliques por frase.
  PerformanceAudio? _audio;
  final Map<int, Future<Uint8List?>> _phraseAudio = {};
  int _audioPhrase = -1;


  @override
  PerformanceState build() {

    // Libera timers, assinaturas e áudio quando o provider
    // deixar de ser utilizado.
    ref.onDispose(() {

      _ticker?.cancel();
      _events?.cancel();
    });

    // Estado inicial da performance.
    return const PerformanceState(
      status:
          PerformanceStatus.initial,
    );
  }


  // -------------------------------------------------------
  // CARREGAR MÚSICA
  // -------------------------------------------------------

  Future<void> loadSong(
    Song song,
  ) async {

    // Interrompe qualquer execução anterior.
    await _stopRun();
    _evaluator = null;

    // Coloca a tela em estado de carregamento.
    state =
        const PerformanceState(
      status:
          PerformanceStatus.loading,
    );

    try {

      // Carrega e interpreta a partitura MusicXML.
      final score =
          await ref.read(getMusicScoreProvider).firstAvailable(
        song.partituraCandidates,
      );

      // Divide em frases e extrai a melodia avaliada.
      final settings =
          ref.read(configurationProvider);

      final structure =
          ref.read(scoreAnalyzerProvider).analyze(
        score,
        measuresPerPhrase:
            settings.measuresPerPhrase,
      );

      // BPM do repertório, do arquivo ou padrão.
      final bpm = song.bpmPadrao > 0
          ? song.bpmPadrao
          : (score.tempo ?? 100);

      // Informa que a música está
      // pronta para ser executada.
      state =
          PerformanceState(
        status:
            PerformanceStatus.ready,

        structure:
            structure,

        bpm: bpm,

        initialBpm: bpm,
      );

    } catch (e) {

      // Caso ocorra algum erro,
      // informa o erro para a interface.
      state =
          PerformanceState(
        status:
            PerformanceStatus.error,

        errorMessage:
            e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }


  // -------------------------------------------------------
  // NAVEGAÇÃO ENTRE TRECHOS (antes de iniciar)
  // -------------------------------------------------------

  void showPhrase(int index) {

    final structure = state.structure;

    if (structure == null) return;

    state = state.copyWith(
      viewPhrase: index.clamp(0, structure.phrases.length - 1),
    );
  }


  // Ajuste manual do andamento antes de começar.
  void setBpm(int bpm) {

    state = state.copyWith(
      bpm: bpm.clamp(30, 240),
    );
  }


  // -------------------------------------------------------
  // INICIAR (contagem de entrada + execução)
  // -------------------------------------------------------

  Future<void> start({
    int fromPhrase = 0,
  }) async {

    final structure = state.structure;

    if (structure == null) return;

    final connection = ref.read(connectionProvider);

    if (!connection.isConnected) {

      state = state.copyWith(
        message:
            'Conecte o dispositivo (ou o modo demonstração) para iniciar.',
      );

      return;
    }

    await _stopRun();

    _simulated = connection.isSimulated;
    _settings = ref.read(configurationProvider);

    // Nova execução completa ou repetição de um trecho.
    final feedback = Map<int, NoteFeedback>.of(state.feedback);

    if (fromPhrase == 0 || _evaluator == null) {

      _evaluator = PerformanceEvaluator(
        structure.expectedNotes,
      );

      _evaluatedPhrases.clear();
      feedback.clear();

    } else {

      _evaluator!.resetFromPhrase(fromPhrase);

      _evaluatedPhrases.removeWhere((p) => p >= fromPhrase);

      for (final note in structure.expectedNotes) {
        if (note.phraseIndex >= fromPhrase) {
          for (final id in note.scoreNoteIds) {
            feedback.remove(id);
          }
        }
      }
    }

    final score = structure.score;
    final bpm = state.bpm;

    _timeline = PerformanceTimeline(
      phrases: structure.phrases,
      startPhrase: fromPhrase,
      countInMs: countInBars * score.barBeats * 60000 / bpm,
      initialBpm: bpm,
    );

    _applyTimings(fromPhrase);

    _nextPhrase = fromPhrase;
    _tempoPhrase = null;
    _tempoBpm = null;
    _audioPhrase = -1;
    _phraseAudio.clear();

    state = state.copyWith(
      status: PerformanceStatus.countdown,
      viewPhrase: fromPhrase,
      feedback: feedback,
      clearCursor: true,
      countInBeat: 1,
      countInBar: 1,
      beatInBar: 0,
      elapsed: Duration.zero,
      clearSuggestion: true,
      clearMessage: true,
    );

    // Escuta os eventos do dispositivo.
    final repository = ref.read(connectionRepositoryProvider);

    _events = repository.events.listen(_onEvent);

    // Relógio local: zero no envio do comando de início; é refinado
    // pelas batidas do metrônomo recebidas do dispositivo.
    _clock
      ..reset()
      ..start();

    _offsetMs = null;

    try {

      await repository.startSession(
        SessionConfig(
          bpm: _metronomeBpm(bpm),
          beatsPerBar: score.beatsPerBar,
          countInBars: countInBars,
          metronomeSound: _settings.metronomeSound,
          metronomeVisual: _settings.metronomeVisual,
        ),
      );

    } catch (e) {

      await _stopRun();

      state = state.copyWith(
        status: PerformanceStatus.ready,
        message: e.toString().replaceFirst('Exception: ', ''),
      );

      return;
    }

    // Modo demonstração: o "aluno virtual" toca a partitura.
    if (_simulated) {
      repository.scheduleSimulation(_simulationNotes(fromPhrase));
    }

    _prepareAudio(fromPhrase);

    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }


  // Andamento do metrônomo na unidade de tempo do compasso
  // (ex.: em 6/8 a batida é a colcheia).
  int _metronomeBpm(int quarterBpm) {

    final beatType = state.structure?.score.beatType ?? 4;

    return max(20, (quarterBpm * beatType / 4).round());
  }


  int get _nowMs =>
      _clock.elapsedMilliseconds - (_offsetMs ?? 0);


  // Horário esperado de cada nota a partir de uma frase.
  void _applyTimings(int fromPhrase) {

    final timeline = _timeline;
    final evaluator = _evaluator;

    if (timeline == null || evaluator == null) return;

    for (final note in evaluator.notes) {

      if (note.phraseIndex < fromPhrase) continue;

      evaluator.setTiming(
        note.index,
        timeline.beatToMs(note.startBeat).round(),
        timeline.durationMs(note.startBeat, note.durationBeats).round(),
      );
    }
  }


  List<SimulationNote> _simulationNotes(int fromPhrase) {

    final timeline = _timeline!;

    return [
      for (final note in state.structure!.expectedNotes)
        if (note.phraseIndex >= fromPhrase)
          SimulationNote(
            midi: note.midi,
            onsetMs: timeline.beatToMs(note.startBeat).round(),
            durationMs: timeline.durationMs(note.startBeat, note.durationBeats).round(),
          ),
    ];
  }


  // -------------------------------------------------------
  // CICLO DE ATUALIZAÇÃO
  // -------------------------------------------------------

  void _tick() {

    final timeline = _timeline;
    final evaluator = _evaluator;
    final structure = state.structure;

    if (timeline == null || evaluator == null || structure == null) return;

    final now = _nowMs;

    // ---------------- Contagem de entrada ----------------
    if (state.status == PerformanceStatus.countdown) {

      if (now < timeline.countInMs) {

        final beatMs = 60000 / _metronomeBpm(state.bpm);
        final beatsPerBar = structure.score.beatsPerBar;
        final beat = max(0, (now / beatMs).floor());

        final countInBeat = beat % beatsPerBar + 1;
        final countInBar = beat ~/ beatsPerBar + 1;

        if (countInBeat != state.countInBeat || countInBar != state.countInBar) {
          state = state.copyWith(
            countInBeat: countInBeat,
            countInBar: countInBar,
          );
        }

        return;
      }

      state = state.copyWith(status: PerformanceStatus.running);
    }

    if (state.status != PerformanceStatus.running) return;

    // ---------------- Execução ----------------
    final phrase = timeline.phraseAt(now.toDouble());

    // Áudio da frase atual (música guia / cliques).
    if (phrase != null && phrase != _audioPhrase) {
      _audioPhrase = phrase;
      _playPhraseAudio(phrase);
    }

    // Envia a mudança de andamento meio tempo antes da frase.
    if (_tempoPhrase != null && !_tempoSent) {

      final halfBeat = 30000 / timeline.bpmOf(_tempoPhrase!);

      if (now >= timeline.phraseStartMs(_tempoPhrase!) - halfBeat) {
        _tempoSent = true;
        ref.read(connectionRepositoryProvider).setTempo(_metronomeBpm(_tempoBpm!));
      }
    }

    // Notas cuja janela passou sem serem tocadas.
    final missed = evaluator.advance(now);

    var feedback = state.feedback;

    if (missed.isNotEmpty) {
      feedback = Map.of(feedback);
      for (final comparison in missed) {
        for (final id in comparison.expected.scoreNoteIds) {
          feedback[id] = comparison.feedback;
        }
      }
    }

    state = state.copyWith(
      cursorBeat: timeline.msToBeat(now.toDouble()),
      viewPhrase: phrase ?? state.viewPhrase,
      feedback: feedback,
      bpm: phrase != null ? timeline.bpmOf(phrase) : state.bpm,
      elapsed: Duration(milliseconds: max(0, now - timeline.countInMs.round())),
      precision: missed.isNotEmpty ? _precision() : state.precision,
    );

    // Avaliação ao término de cada frase (RFA07).
    while (_nextPhrase < structure.phrases.length &&
        now > timeline.phraseEndMs(_nextPhrase) + phraseGraceMs) {

      final stopped = _evaluatePhrase(_nextPhrase);

      _nextPhrase++;

      if (stopped) return;
    }

    // Fim da música.
    if (_nextPhrase >= structure.phrases.length) {
      finish(completed: true);
    }
  }


  // Retorna true se a execução foi interrompida.
  bool _evaluatePhrase(int phraseIndex) {

    final result = _evaluator!.evaluatePhrase(phraseIndex);
    final phrases = state.structure!.phrases;

    _evaluatedPhrases.add(phraseIndex);

    // RFA08: abaixo de 50% a execução trava e o aluno repete o trecho.
    if (result.failed) {

      _pause();

      state = state.copyWith(
        status: PerformanceStatus.phraseFailed,
        lastPhrase: result,
        viewPhrase: phraseIndex,
        clearCursor: true,
        precision: _precision(),
      );

      return true;
    }

    String message =
        'Trecho ${phraseIndex + 1}: ${result.score.round()}%';

    int? suggestion;

    // RFA09 / RU12: trecho aprovado, mas instável.
    if (result.unstable) {

      final newBpm = max(40, (state.bpm * 0.9).round());

      // A frase seguinte já está em andamento: a mudança vale
      // a partir do próximo trecho.
      final target = phraseIndex + 2;

      if (newBpm < state.bpm && target < phrases.length) {

        if (_settings.autoTempo) {

          _scheduleTempo(target, newBpm);

          message = 'Trecho ${phraseIndex + 1} com instabilidade: '
              'andamento reduzido para $newBpm BPM a partir do próximo trecho.';

        } else {

          suggestion = newBpm;

          message = 'Trecho ${phraseIndex + 1} com instabilidade. '
              'Que tal diminuir para $newBpm BPM?';
        }
      } else {

        message = 'Trecho ${phraseIndex + 1} com instabilidade. '
            'Na próxima vez, experimente um andamento menor.';
      }
    }

    state = state.copyWith(
      lastPhrase: result,
      message: message,
      suggestedBpm: suggestion,
      clearSuggestion: suggestion == null,
      precision: _precision(),
    );

    return false;
  }


  // Aceita a sugestão de redução de BPM (RFA09).
  void acceptTempoSuggestion() {

    final bpm = state.suggestedBpm;
    final timeline = _timeline;

    if (bpm == null || timeline == null) return;

    final now = _nowMs.toDouble();
    final current = timeline.phraseAt(now) ?? _nextPhrase;
    var target = current + 1;

    // Muito perto da troca de frase: aplica na seguinte.
    if (target < timeline.phrases.length &&
        timeline.phraseStartMs(target) - now < 60000 / state.bpm) {
      target++;
    }

    if (target < timeline.phrases.length) {

      _scheduleTempo(target, bpm);

      state = state.copyWith(
        clearSuggestion: true,
        message: 'Andamento de $bpm BPM a partir do próximo trecho.',
      );

    } else {

      state = state.copyWith(clearSuggestion: true, clearMessage: true);
    }
  }


  void dismissMessage() {

    state = state.copyWith(clearSuggestion: true, clearMessage: true);
  }


  void _scheduleTempo(int phraseIndex, int bpm) {

    final timeline = _timeline!;

    timeline.setBpmFrom(phraseIndex, bpm);

    _applyTimings(phraseIndex);

    _tempoPhrase = phraseIndex;
    _tempoBpm = bpm;
    _tempoSent = false;

    // Áudio das frases seguintes precisa ser gerado no novo andamento.
    _phraseAudio.removeWhere((p, _) => p >= phraseIndex);

    if (_simulated) {
      ref.read(connectionRepositoryProvider).scheduleSimulation(
            _simulationNotes(phraseIndex),
          );
    }
  }


  // -------------------------------------------------------
  // EVENTOS DO DISPOSITIVO
  // -------------------------------------------------------

  void _onEvent(DeviceEvent event) {

    final active = state.status == PerformanceStatus.countdown ||
        state.status == PerformanceStatus.running;

    if (!active) return;

    switch (event) {

      case BeatEvent():

        // Alinha o relógio local ao do dispositivo. O menor desvio
        // observado corresponde à menor latência de rede.
        final offset = _clock.elapsedMilliseconds - event.timeMs;

        if (_offsetMs == null || offset < _offsetMs!) {
          _offsetMs = offset;
        }

        state = state.copyWith(
          beatInBar: event.beatInBar + 1,
          beatCount: state.beatCount + 1,
        );

      case NotePlayedEvent():

        final timeline = _timeline;

        // Notas durante a contagem de entrada são ignoradas.
        if (timeline == null || event.timeMs < timeline.countInMs - 250) return;

        final comparison = _evaluator?.onNoteOn(
          midi: event.midi,
          onsetMs: event.timeMs,
          frequency: event.frequency,
        );

        _applyComparison(
          comparison,
          playedMidi: event.midi,
          countNote: true,
        );

      case NoteReleasedEvent():

        final comparison = _evaluator?.onNoteOff(
          midi: event.midi,
          durationMs: event.durationMs,
          timeMs: event.timeMs,
        );

        if (comparison != null) {
          _applyComparison(comparison, playedMidi: event.midi, countNote: false);
        }

      case ConnectionLostEvent():

        _stopRun();

        state = state.copyWith(
          status: PerformanceStatus.ready,
          clearCursor: true,
          message: 'A conexão com o dispositivo foi perdida. '
              'Reconecte para continuar.',
        );

      case DeviceStatusEvent():
        break;
    }
  }


  void _applyComparison(
    NoteComparison? comparison, {
    required int playedMidi,
    required bool countNote,
  }) {

    var feedback = state.feedback;

    if (comparison != null) {
      feedback = Map.of(feedback);
      for (final id in comparison.expected.scoreNoteIds) {
        feedback[id] = comparison.feedback;
      }
    }

    state = state.copyWith(
      feedback: feedback,
      notesPlayed: countNote ? state.notesPlayed + 1 : state.notesPlayed,
      lastPlayedMidi: countNote ? playedMidi : state.lastPlayedMidi,
      // Nota sem correspondência na partitura = nota errada.
      lastFeedback: countNote
          ? (comparison?.feedback ?? NoteFeedback.incorrect)
          : state.lastFeedback,
      precision: _precision(),
    );
  }


  // Precisão parcial das notas já avaliadas.
  double _precision() {

    final comparisons = _evaluator?.comparisons ?? const [];

    if (comparisons.isEmpty) return 0;

    final total = comparisons.fold(0.0, (sum, c) => sum + c.score);

    return total / comparisons.length * 100;
  }


  // -------------------------------------------------------
  // ÁUDIO (música guia e cliques do modo demonstração)
  // -------------------------------------------------------

  bool get _needsAudio =>
      _settings.guideAudio || (_simulated && _settings.metronomeSound);

  void _prepareAudio(int fromPhrase) {

    if (!_needsAudio && !_simulated) return;

    _audio ??= ref.read(performanceAudioProvider);

    // Sem o buzzer do dispositivo, o app toca a contagem (RU07).
    if (_simulated) {

      final beats = countInBars * state.structure!.score.beatsPerBar;
      final beatMs = 60000 / _metronomeBpm(state.bpm);

      final request = SynthRequest(
        notes: const [],
        clicks: [
          for (var i = 0; i < beats; i++)
            SynthClick(
              timeMs: (i * beatMs).round(),
              accent: i % state.structure!.score.beatsPerBar == 0,
            ),
        ],
        totalMs: (beats * beatMs).round(),
      );

      _audio!.render(request).then((wav) {
        if (state.status == PerformanceStatus.countdown) {
          _audio?.play(wav);
        }
      });
    }

    if (_needsAudio) {
      _phraseAudio[fromPhrase] = _renderPhrase(fromPhrase);
    }
  }


  Future<Uint8List?> _renderPhrase(int phraseIndex) async {

    final timeline = _timeline;
    final structure = state.structure;

    if (timeline == null || structure == null) return null;

    final phrase = structure.phrases[phraseIndex];
    final start = timeline.phraseStartMs(phraseIndex);
    final notes = <SynthNote>[];

    if (_settings.guideAudio) {

      for (final note in structure.score.notes) {

        // Continuações de ligadura não são reatacadas.
        if (note.isRest || note.tieStop) continue;
        if (note.startBeat < phrase.startBeat - 1e-6 || note.startBeat >= phrase.endBeat - 1e-6) {
          continue;
        }

        notes.add(
          SynthNote(
            midi: note.midi,
            startMs: (timeline.beatToMs(note.startBeat) - start).round(),
            durationMs: timeline.durationMs(note.startBeat, note.durationBeats).round(),
            velocity: structure.evaluatedNoteIds.contains(note.id) ? 0.8 : 0.55,
          ),
        );
      }
    }

    final clicks = <SynthClick>[];

    if (_simulated && _settings.metronomeSound) {

      final beatMs = 60000 / _metronomeBpm(timeline.bpmOf(phraseIndex));
      final beatsPerBar = structure.score.beatsPerBar;
      final total = timeline.phraseEndMs(phraseIndex) - start;
      final firstMeasure = structure.score.measures[phrase.firstMeasure];

      // Alinha o tempo forte ao início do compasso.
      final offsetBeats = ((phrase.startBeat - firstMeasure.startBeat) / (4 / firstMeasure.beatType)).round();

      for (var i = 0; i * beatMs < total - 1; i++) {
        clicks.add(
          SynthClick(
            timeMs: (i * beatMs).round(),
            accent: (i + offsetBeats) % beatsPerBar == 0,
          ),
        );
      }
    }

    if (notes.isEmpty && clicks.isEmpty) return null;

    return _audio!.render(
      SynthRequest(
        notes: notes,
        clicks: clicks,
        totalMs: (timeline.phraseEndMs(phraseIndex) - start).round(),
      ),
    );
  }


  Future<void> _playPhraseAudio(int phraseIndex) async {

    if (!_needsAudio || _audio == null) return;

    final future = _phraseAudio[phraseIndex] ?? _renderPhrase(phraseIndex);

    _phraseAudio[phraseIndex] = future;

    // Prepara a próxima frase enquanto esta toca.
    final next = phraseIndex + 1;

    if (next < (state.structure?.phrases.length ?? 0) && !_phraseAudio.containsKey(next)) {
      _phraseAudio[next] = _renderPhrase(next);
    }

    final wav = await future;

    if (wav != null &&
        state.status == PerformanceStatus.running &&
        _audioPhrase == phraseIndex) {
      await _audio?.play(wav);
    }
  }


  // -------------------------------------------------------
  // PAUSA / REPETIÇÃO / FIM
  // -------------------------------------------------------

  void _pause() {

    _ticker?.cancel();
    _ticker = null;
    _events?.cancel();
    _events = null;
    _audio?.stop();

    ref.read(connectionRepositoryProvider).stopSession();
  }


  Future<void> _stopRun() async {

    final wasActive = _ticker != null || _events != null;

    _ticker?.cancel();
    _ticker = null;
    await _events?.cancel();
    _events = null;
    await _audio?.stop();
    _clock.stop();

    if (wasActive) {
      await ref.read(connectionRepositoryProvider).stopSession();
    }
  }


  // Repete o trecho em que a execução parou (RU11 / RFA08).
  Future<void> retryPhrase({
    bool slower = false,
  }) async {

    final phrase = state.lastPhrase?.phraseIndex ?? state.viewPhrase;

    if (slower) {
      state = state.copyWith(bpm: max(40, (state.bpm * 0.9).round()));
    }

    await start(fromPhrase: phrase);
  }


  // -------------------------------------------------------
  // FINALIZAR PERFORMANCE
  // -------------------------------------------------------

  Future<void> finish({
    required bool completed,
  }) async {

    final evaluator = _evaluator;
    final timeline = _timeline;

    // Frase em andamento entra no resultado se o aluno parou antes.
    final phrases = {..._evaluatedPhrases};

    if (!completed && timeline != null) {
      final current = timeline.phraseAt(_nowMs.toDouble());
      if (current != null) {
        evaluator?.advance(_nowMs);
        phrases.add(current);
      }
    }

    await _stopRun();

    final result = evaluator == null
        ? ScoreResult.empty
        : evaluator.buildResult(
            phrases: phrases.toList()..sort(),
            completed: completed,
          );

    state = state.copyWith(
      status: PerformanceStatus.finished,
      result: result,
      precision: result.overall,
      clearCursor: true,
      clearMessage: true,
      clearSuggestion: true,
    );
  }


  // Botão PARAR.
  Future<void> stop() => finish(completed: false);


  // -------------------------------------------------------
  // SALVAR PERFORMANCE
  // -------------------------------------------------------

  Future<String> savePerformance({

    required String userId,

    required String songId,

    required int bpmInicial,

    required double pontuacaoFinal,

  }) async {

    // Recupera o caso de uso responsável
    // por salvar a execução.
    final savePerformance =
        ref.read(
      savePerformanceProvider,
    );

    final result = state.result;

    // Executa o salvamento.
    return savePerformance(

      userId:
          userId,

      songId:
          songId,

      bpmInicial:
          bpmInicial,

      pontuacaoFinal:
          pontuacaoFinal,

      status:
          (result?.completed ?? false) ? 'concluida' : 'interrompida',

      pontuacaoAltura:
          result?.pitchAccuracy,

      pontuacaoRitmo:
          result?.rhythmAccuracy,

      bpmFinal:
          state.bpm,

      notasTocadas:
          state.notesPlayed,

      notasCorretas:
          result?.notesCorrect,
    );
  }


  // -------------------------------------------------------
  // RESETAR
  // -------------------------------------------------------

  Future<void> reset() async {

    // Interrompe a execução e o dispositivo.
    await _stopRun();

    _evaluator = null;
    _timeline = null;

    // Volta ao estado inicial.
    state =
        const PerformanceState(
      status:
          PerformanceStatus.initial,
    );
  }
}


// ---------------------------------------------------------
// PERFORMANCE PROVIDER
// ---------------------------------------------------------

final performanceProvider =
    NotifierProvider<
        PerformanceNotifier,
        PerformanceState>(
  PerformanceNotifier.new,
);

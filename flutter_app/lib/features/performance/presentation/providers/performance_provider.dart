import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/features/history/presentation/providers/history_provider.dart';

import '../../../configuration/domain/entities/performance_settings.dart';
import '../../../configuration/presentation/providers/configuration_provider.dart';
import '../../../connection/domain/entities/device_event.dart';
import '../../../connection/domain/entities/expected_note_cue.dart';
import '../../../connection/domain/entities/session_config.dart';
import '../../../connection/domain/entities/simulation_note.dart';
import '../../../connection/presentation/providers/connection_provider.dart';
import '../../../execution_log/domain/services/execution_console_log.dart';
import '../../../execution_log/presentation/providers/execution_log_provider.dart';
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
import '../../data/services/session_audio.dart';

import '../../domain/entities/performance_state.dart';

import '../../domain/repositories/midi_repository.dart';

import '../../domain/services/midi_parser.dart';
import '../../domain/services/performance_timeline.dart';

import '../../domain/usecases/get_midi_file.dart';

import 'performance_live_clock.dart';


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

  // Tempo extra após o fim da frase para receber as últimas notas (inclui o
  // tempo de entrega dos eventos do dispositivo pela rede).
  static const phraseGraceMs = 500;

  // Intervalo da lógica da execução (notas perdidas, fim de frase, áudio).
  // O cursor e o metrônomo visual são atualizados a cada quadro da tela
  // pelo relógio ao vivo (`live`), sem reconstruir a tela.
  static const tickInterval = Duration(milliseconds: 30);

  // Cursor, metrônomo visual, contagem e tempo decorrido (mudam a cada
  // quadro; ficam fora do estado para não reconstruir a tela inteira).
  final PerformanceLiveClock live = PerformanceLiveClock();

  // Fim da próxima nota esperada: o cursor do estado (usado no destaque da
  // próxima nota) só é atualizado quando passa deste ponto.
  PerformanceState? _boundaryState;
  double _boundary = double.infinity;

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

  // Mudança de andamento agendada (frase) e se o reenvio já foi feito.
  int? _tempoPhrase;
  bool _tempoResent = false;

  // Log da execução no console (esperado x captado) e frases cujas notas
  // esperadas já foram enviadas ao monitor serial do dispositivo.
  ExecutionConsoleLog? _log;
  int _nextLogNote = 0;
  final Set<int> _cuedPhrases = {};
  int _cueCheckPhrase = -1;

  // Áudio da execução (contagem de entrada, metrônomo e música guia) em um
  // único arquivo (SessionAudioPlan), gerado e carregado no player assim que
  // a música fica pronta (e ao mudar o BPM ou o trecho inicial): o primeiro
  // clique sai junto com o INICIAR e a música começa na amostra exata em
  // que a contagem termina.
  PerformanceAudio? _audio;
  Future<_RenderedAudio>? _sessionWav;
  Object? _sessionKey;
  Timer? _warmTimer;

  // Instante da sessão (ms) do início do arquivo que está tocando.
  double? _audioBaseMs;

  // Andamento novo no meio da execução: arquivo a partir da frase da mudança.
  int? _tempoAudioPhrase;
  Future<_RenderedAudio?>? _tempoAudio;

  // Correção do alinhamento do áudio com o relógio da sessão.
  int _lastAlignMs = -100000;
  bool _aligning = false;
  int _audioCorrections = 0;

  // Atraso de entrega das notas medido (relógio da sessão na chegada menos
  // instante do ataque): define quando uma nota não tocada vira "Perdeu".
  final List<int> _noteLags = [];

  // Último ciclo da lógica (relógio local), para rodar no ritmo da tela.
  int _lastTickClockMs = -1000;


  @override
  PerformanceState build() {

    // Libera timers, assinaturas e áudio quando o provider
    // deixar de ser utilizado.
    ref.onDispose(() {

      _ticker?.cancel();
      _events?.cancel();
      _warmTimer?.cancel();
      live.clear();
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

      _warmAudio(debounce: false);

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

    _warmAudio();
  }


  // Ajuste manual do andamento antes de começar.
  void setBpm(int bpm) {

    state = state.copyWith(
      bpm: bpm.clamp(30, 240),
    );

    _warmAudio();
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

    // Áudio da execução pronto no player antes do comando de início.
    _warmTimer?.cancel();
    final sessionAudio = await _sessionAudio(fromPhrase: fromPhrase, preload: true);

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

    // BPM inteiro do metrônomo do dispositivo. A contagem e o horário de
    // cada nota são calculados com exatamente este valor, o mesmo que o
    // firmware usa ao iniciar a coleta (sincronismo app × firmware).
    final metronomeBpm = PerformanceTimeline.metronomeBpmFor(bpm, score.beatType);

    _timeline = _newTimeline(fromPhrase, bpm);

    _applyTimings(fromPhrase);

    _log = ref.read(executionConsoleLogProvider);
    final firstNote = structure.expectedNotes.indexWhere((n) => n.phraseIndex >= fromPhrase);
    _nextLogNote = firstNote < 0 ? structure.expectedNotes.length : firstNote;
    _cuedPhrases.clear();
    _cueCheckPhrase = -1;

    _nextPhrase = fromPhrase;
    _tempoPhrase = null;
    _audioBaseMs = null;
    _tempoAudioPhrase = null;
    _tempoAudio = null;
    _lastAlignMs = -100000;

    state = state.copyWith(
      status: PerformanceStatus.countdown,
      viewPhrase: fromPhrase,
      feedback: feedback,
      streak: 0,
      bestStreak: fromPhrase == 0 ? 0 : state.bestStreak,
      clearJudgement: true,
      phraseScores: {
        for (final e in state.phraseScores.entries)
          if (fromPhrase > 0 && e.key < fromPhrase) e.key: e.value,
      },
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

    _log?.start(
      bpm: bpm,
      metronomeBpm: metronomeBpm,
      beatsPerBar: score.beatsPerBar,
      beatType: score.beatType,
      countInBars: countInBars,
      countInMs: _timeline!.countInMs.round(),
      fromPhrase: fromPhrase,
      simulated: _simulated,
    );

    try {

      await repository.startSession(
        SessionConfig(
          bpm: metronomeBpm,
          beatsPerBar: score.beatsPerBar,
          countInBars: countInBars,
          beatType: score.beatType,
          metronomeSound: _settings.metronomeSound,
          metronomeVisual: _settings.metronomeVisual,
        ),
      );

    } catch (e) {

      _log = null;
      await _stopRun();

      state = state.copyWith(
        status: PerformanceStatus.ready,
        message: e.toString().replaceFirst('Exception: ', ''),
      );

      return;
    }

    // Áudio da execução (contagem de entrada sonora – RU07 – e música) a
    // partir do ponto da sessão em que está; o alinhamento às batidas do
    // dispositivo é corrigido assim que elas chegam (_checkAudioAlignment).
    final audioLog = _log;
    void logAudio({required bool playing, Object? error}) => audioLog?.audio(
          metronome: _settings.metronomeSound,
          guide: _settings.guideAudio,
          playing: playing,
          error: error,
        );

    final audio = _audio;
    if (sessionAudio != null && audio != null && state.status == PerformanceStatus.countdown) {
      _audioBaseMs = sessionAudio.baseMs;
      audio
          .play(sessionAudio.wav, position: Duration(milliseconds: max(0, _nowMs)))
          .then((ok) => logAudio(playing: ok, error: audio.lastError));
    } else if (state.status == PerformanceStatus.countdown) {
      logAudio(playing: false);
    }

    // Modo demonstração: o "aluno virtual" toca a partitura.
    if (_simulated) {
      repository.scheduleSimulation(_simulationNotes(fromPhrase));
    }

    // Monitor serial do dispositivo: notas do primeiro trecho (as dos
    // seguintes vão no início do trecho anterior).
    _cuePhrase(fromPhrase);

    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }


  int get _nowMs =>
      _clock.elapsedMilliseconds - (_offsetMs ?? 0);


  // Linha do tempo de uma execução a partir de `fromPhrase` em `bpm`.
  PerformanceTimeline _newTimeline(int fromPhrase, int bpm) {

    final structure = state.structure!;
    final score = structure.score;

    // BPM inteiro do metrônomo do dispositivo. A contagem e o horário de
    // cada nota são calculados com exatamente este valor, o mesmo que o
    // firmware usa ao iniciar a coleta (sincronismo app × firmware).
    final metronomeBpm = PerformanceTimeline.metronomeBpmFor(bpm, score.beatType);

    return PerformanceTimeline(
      phrases: structure.phrases,
      startPhrase: fromPhrase,
      countInMs: countInBars * score.beatsPerBar * 60000 / metronomeBpm,
      initialBpm: bpm,
      beatType: score.beatType,
    );
  }


  // Lógica da execução no ritmo da tela: chamado a cada quadro pela tela de
  // execução. A troca de trecho, o destaque da próxima nota e as notas
  // perdidas são vistos no quadro em que acontecem (o temporizador de 30 ms
  // continua valendo quando não há quadros, ex.: aba em segundo plano).
  void onFrame() {

    if (_ticker == null) {
      sampleLiveClock();
      return;
    }

    if (_clock.elapsedMilliseconds - _lastTickClockMs >= 8) {
      _tick();
    } else {
      sampleLiveClock();
    }
  }


  // Correções de alinhamento feitas no áudio (diagnóstico e testes).
  int get audioCorrections => _audioCorrections;

  // Tempo atual que uma nota não tocada espera antes de virar "Perdeu".
  int? get deliveryLatencyMs => _evaluator?.deliveryLatencyMs;


  // Atualiza o relógio ao vivo. Chamado a cada quadro pela tela de execução
  // (movimento suave do cursor) e a cada ciclo da lógica.
  void sampleLiveClock() {

    final timeline = _timeline;
    final active = state.status == PerformanceStatus.countdown ||
        state.status == PerformanceStatus.running;

    if (timeline == null || !active || !_clock.isRunning) {
      live.clear();
      return;
    }

    final now = _nowMs.toDouble();

    live.update(
      cursor: state.status == PerformanceStatus.running ? timeline.msToBeat(now) : null,
      beat: timeline.metronomeBeatAt(now),
      elapsed: max(0, (now - timeline.countInMs) ~/ 1000),
    );
  }


  double _cursorBoundary() {

    if (!identical(_boundaryState, state)) {
      _boundaryState = state;
      _boundary = state.nextExpectedNote?.endBeat ?? double.infinity;
    }

    return _boundary;
  }


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


  // Envia ao dispositivo as notas esperadas de um trecho (monitor serial).
  void _cuePhrase(int phraseIndex) {

    final evaluator = _evaluator;
    final structure = state.structure;

    if (evaluator == null || structure == null) return;
    if (phraseIndex < 0 || phraseIndex >= structure.phrases.length) return;

    _cuedPhrases.add(phraseIndex);

    ref.read(connectionRepositoryProvider).sendExpectedNotes([
      for (final note in evaluator.notes)
        if (note.phraseIndex == phraseIndex)
          ExpectedNoteCue(
            index: note.index,
            midi: note.midi,
            onsetMs: evaluator.onsetOf(note.index) ?? 0,
            durationMs: evaluator.durationOf(note.index) ?? 0,
            durationBeats: note.durationBeats,
          ),
    ]);
  }


  // Registra no console as notas esperadas cuja hora chegou.
  void _logDueNotes(int now) {

    final evaluator = _evaluator;
    final log = _log;

    if (evaluator == null || log == null) return;

    final notes = evaluator.notes;

    while (_nextLogNote < notes.length) {
      final note = notes[_nextLogNote];
      final onset = evaluator.onsetOf(note.index);
      if (onset == null || onset > now) break;
      log.expected(note, onsetMs: onset, durationMs: evaluator.durationOf(note.index) ?? 0);
      _nextLogNote++;
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

    _lastTickClockMs = _clock.elapsedMilliseconds;
    _checkAudioAlignment();

    // ---------------- Contagem de entrada ----------------
    // Tempo e compasso da contagem vêm do relógio ao vivo.
    if (state.status == PerformanceStatus.countdown) {

      if (now < timeline.countInMs) {
        sampleLiveClock();
        return;
      }

      state = state.copyWith(status: PerformanceStatus.running);
    }

    sampleLiveClock();

    if (state.status != PerformanceStatus.running) return;

    // ---------------- Execução ----------------
    final phrase = timeline.phraseAt(now.toDouble());

    // Andamento novo: o áudio gerado no novo BPM começa na frase da mudança.
    if (_tempoAudioPhrase != null && phrase != null && phrase >= _tempoAudioPhrase!) {
      _switchTempoAudio();
    }

    // Monitor serial: notas do próximo trecho antes de ele começar.
    if (phrase != null && phrase != _cueCheckPhrase) {
      _cueCheckPhrase = phrase;
      _cuePhrase(phrase + 1);
    }

    // Reenvia a mudança de andamento meio tempo antes da frase (o primeiro
    // envio, no agendamento, pode se perder na rede UDP).
    if (_tempoPhrase != null && !_tempoResent) {

      final halfBeat = 30000 / timeline.metronomeBpmOf(_tempoPhrase!);

      if (now >= timeline.phraseStartMs(_tempoPhrase!) - halfBeat) {
        _tempoResent = true;
        _sendTempo();
      }
    }

    // Notas cuja janela passou sem serem tocadas.
    final missed = evaluator.advance(now);

    _logDueNotes(now);
    for (final comparison in missed) {
      _log?.missed(comparison, onsetMs: evaluator.onsetOf(comparison.expected.index) ?? 0);
    }

    var feedback = state.feedback;
    NoteJudgement? judgement;

    if (missed.isNotEmpty) {
      feedback = Map.of(feedback);
      for (final comparison in missed) {
        for (final id in comparison.expected.scoreNoteIds) {
          feedback[id] = comparison.feedback;
        }
      }
      judgement = NoteJudgement(
        serial: (state.judgement?.serial ?? 0) + 1,
        noteId: missed.last.expected.scoreNoteIds.first,
        feedback: NoteFeedback.missed,
        label: NoteJudgement.labelFor(missed.last),
      );
    }

    // O estado (que reconstrói a tela) só muda quando algo visível muda:
    // nota perdida, troca de trecho ou de andamento, ou o cursor passou do
    // fim da próxima nota (destaque da nota seguinte).
    final cursor = timeline.msToBeat(now.toDouble());
    final viewPhrase = phrase ?? state.viewPhrase;
    final bpm = phrase != null ? timeline.bpmOf(phrase) : state.bpm;
    final cursorMoved = cursor != null &&
        (state.cursorBeat == null || cursor >= _cursorBoundary());

    if (missed.isNotEmpty ||
        cursorMoved ||
        viewPhrase != state.viewPhrase ||
        bpm != state.bpm) {

      state = state.copyWith(
        judgement: judgement,
        streak: missed.isNotEmpty ? 0 : state.streak,
        cursorBeat: cursor,
        viewPhrase: viewPhrase,
        feedback: feedback,
        bpm: bpm,
        precision: missed.isNotEmpty ? _precision() : state.precision,
      );
    }

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

    _log?.phrase(result);

    _evaluatedPhrases.add(phraseIndex);

    state = state.copyWith(
      phraseScores: {...state.phraseScores, phraseIndex: result.score},
    );

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

    // Sem aviso sobre a partitura ao fim de cada trecho: o percentual fica
    // na barra de progresso por trechos e não cobre o início do seguinte.
    int? suggestion;

    // RFA09 / RU12: trecho aprovado, mas instável.
    if (result.unstable) {

      final newBpm = max(40, (state.bpm * 0.9).round());

      // A frase seguinte já está em andamento: a mudança vale
      // a partir do próximo trecho.
      final target = phraseIndex + 2;

      if (newBpm < state.bpm && target < phrases.length) {

        if (_settings.autoTempo) {
          // O novo BPM aparece no indicador de andamento (com a seta de
          // redução) quando o trecho começa.
          _scheduleTempo(target, newBpm);
        } else {
          // Sugestão exibida nos controles, abaixo da partitura.
          suggestion = newBpm;
        }
      }
    }

    state = state.copyWith(
      lastPhrase: result,
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

      state = state.copyWith(clearSuggestion: true);

    } else {

      state = state.copyWith(clearSuggestion: true, clearMessage: true);
    }
  }


  void dismissMessage() {

    state = state.copyWith(clearSuggestion: true, clearMessage: true);
  }


  // Envia o andamento da frase agendada com a batida exata em que ele
  // começa (contagem incluída), a mesma posição usada pela linha do tempo.
  void _sendTempo() {

    final timeline = _timeline;
    final phrase = _tempoPhrase;
    final structure = state.structure;

    if (timeline == null || phrase == null || structure == null) return;

    final atBeat = countInBars * structure.score.beatsPerBar +
        timeline.metronomeBeatsBetween(timeline.startPhrase, phrase);

    ref.read(connectionRepositoryProvider).setTempo(
          timeline.metronomeBpmOf(phrase),
          atBeat: atBeat,
        );
  }


  void _scheduleTempo(int phraseIndex, int bpm) {

    final timeline = _timeline!;

    timeline.setBpmFrom(phraseIndex, bpm);

    _applyTimings(phraseIndex);

    // Notas já enviadas ao monitor serial com o andamento anterior.
    for (final phrase in _cuedPhrases.where((p) => p >= phraseIndex).toList()) {
      _cuePhrase(phrase);
    }

    _tempoPhrase = phraseIndex;
    _tempoResent = false;

    // Envia já: o dispositivo guarda o novo BPM e troca exatamente na
    // batida do início da frase.
    _sendTempo();

    // Áudio a partir da frase da mudança no novo andamento, carregado no
    // outro player: troca no início da frase (a única troca de arquivo da
    // execução). Duas mudanças antes da troca: o arquivo começa na primeira.
    final audio = _audio;

    if (audio != null && _audioBaseMs != null) {

      final from = min(phraseIndex, _tempoAudioPhrase ?? phraseIndex);
      final plan = _audioPlan(timeline, from, countIn: false);

      if (plan != null) {
        _tempoAudioPhrase = from;
        _tempoAudio = audio.render(plan.request).then<_RenderedAudio?>((wav) async {
          await audio.preload(wav);
          return (baseMs: plan.baseMs, wav: wav);
        }, onError: (Object _) => null);
      }
    }

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
        // observado corresponde à menor latência de rede. O metrônomo
        // visual é calculado pelo relógio (sem reconstruir a tela a cada
        // batida nem depender do atraso de cada pacote).
        final offset = _clock.elapsedMilliseconds - event.timeMs;

        if (_offsetMs == null || offset < _offsetMs!) {
          final first = _offsetMs == null;
          final change = first ? offset : _offsetMs! - offset;
          _offsetMs = offset;
          // O relógio da sessão andou: o áudio (iniciado pelo relógio local,
          // antes da primeira batida) é realinhado às batidas do dispositivo.
          if (change.abs() >= 10) _checkAudioAlignment(force: true);
        }

      case NotePlayedEvent():

        final timeline = _timeline;

        // Notas durante a contagem de entrada são ignoradas. A margem é a
        // janela máxima de avaliação: a primeira nota tocada um pouco antes
        // do tempo ainda é comparada com a primeira nota da música.
        final margin = _evaluator?.tolerance.maxWindowMs ?? 400;
        if (timeline == null) return;
        if (event.timeMs < timeline.countInMs - margin) {
          _log?.captured(
            midi: event.midi,
            frequency: event.frequency,
            timeMs: event.timeMs,
            comparison: null,
            verdict: '',
            countIn: true,
          );
          return;
        }

        _measureNoteLag(event.timeMs);

        final comparison = _evaluator?.onNoteOn(
          midi: event.midi,
          onsetMs: event.timeMs,
          frequency: event.frequency,
        );

        _log?.captured(
          midi: event.midi,
          frequency: event.frequency,
          timeMs: event.timeMs,
          comparison: comparison,
          verdict: NoteJudgement.labelFor(comparison),
        );

        _applyComparison(
          comparison,
          playedMidi: event.midi,
          countNote: true,
        );

      case NoteReleasedEvent():

        _logRelease(event);

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


  // Duração medida convertida em figura no andamento do trecho.
  void _logRelease(NoteReleasedEvent event) {

    final timeline = _timeline;
    final log = _log;

    if (timeline == null || log == null) return;

    final onset = (event.timeMs - event.durationMs).toDouble();
    final beat = timeline.msToBeat(max(onset, timeline.countInMs)) ??
        timeline.phrases[timeline.startPhrase].startBeat;

    log.released(
      midi: event.midi,
      durationMs: event.durationMs,
      timeMs: event.timeMs,
      quarterMs: timeline.durationMs(beat, 1),
    );
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

    // Sequência de acertos e selo da nota (somente no ataque).
    var streak = state.streak;
    NoteJudgement? judgement;

    if (countNote) {
      final result = comparison?.feedback ?? NoteFeedback.incorrect;
      if (result == NoteFeedback.correct) {
        streak++;
      } else if (result != NoteFeedback.approximate) {
        streak = 0;
      }
      judgement = NoteJudgement(
        serial: (state.judgement?.serial ?? 0) + 1,
        noteId: comparison?.expected.scoreNoteIds.first,
        feedback: result,
        label: NoteJudgement.labelFor(comparison),
      );
    }

    state = state.copyWith(
      feedback: feedback,
      streak: streak,
      bestStreak: max(streak, state.bestStreak),
      judgement: judgement,
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

  // Plano de áudio da execução (vazio = nada a tocar). Contagem: sempre no
  // modo demonstração (sem o buzzer do dispositivo); com o dispositivo, se
  // o metrônomo sonoro estiver ligado. Com o dispositivo o microfone ouve o
  // alto-falante: clique sem altura.
  SessionAudioPlan? _audioPlan(PerformanceTimeline timeline, int fromPhrase, {required bool countIn}) {

    final structure = state.structure;

    if (structure == null) return null;

    final simulated = ref.read(connectionProvider).isSimulated;
    final settings = ref.read(configurationProvider);

    final plan = SessionAudioPlan.build(
      structure: structure,
      timeline: timeline,
      fromPhrase: fromPhrase,
      countIn: countIn,
      countInClicks: simulated || settings.metronomeSound,
      clicks: settings.metronomeSound,
      guide: settings.guideAudio,
      clickSound: simulated ? ClickSound.tone : ClickSound.wood,
    );

    return plan.isEmpty ? null : plan;
  }


  // Áudio da execução a partir de `fromPhrase` no BPM atual (gerado uma vez
  // por combinação de trecho, BPM e opções de som).
  Future<_RenderedAudio?> _sessionAudio({required int fromPhrase, required bool preload}) async {

    final structure = state.structure;

    if (structure == null) return null;

    final plan = _audioPlan(_newTimeline(fromPhrase, state.bpm), fromPhrase, countIn: true);

    if (plan == null) return null;

    final audio = _audio ?? ref.read<PerformanceAudio>(performanceAudioProvider);
    _audio = audio;

    final request = plan.request;
    final key = (
      identityHashCode(structure),
      fromPhrase,
      state.bpm,
      request.clicks.length,
      request.notes.length,
      request.clickSound,
      request.totalMs,
    );

    if (key != _sessionKey || _sessionWav == null) {
      _sessionKey = key;
      _sessionWav = audio.render(request).then((wav) => (baseMs: plan.baseMs, wav: wav));
    }

    final pending = _sessionWav!;

    try {

      final rendered = await pending;

      // Outro áudio foi pedido enquanto este era gerado (BPM ou trecho mudou).
      if (!identical(pending, _sessionWav)) return null;

      if (preload) await audio.preload(rendered.wav);

      return rendered;

    } catch (_) {

      return null;
    }
  }


  // Gera e carrega o áudio antes do INICIAR (com uma pequena espera quando
  // o BPM ou o trecho estão sendo ajustados, para não gerar a cada toque).
  void _warmAudio({bool debounce = true}) {

    _warmTimer?.cancel();

    if (state.status != PerformanceStatus.ready) return;

    _warmTimer = Timer(
      debounce ? const Duration(milliseconds: 250) : Duration.zero,
      () {
        if (state.status == PerformanceStatus.ready) {
          _sessionAudio(fromPhrase: state.viewPhrase, preload: true);
        }
      },
    );
  }


  void _switchTempoAudio() {

    final future = _tempoAudio;

    _tempoAudioPhrase = null;
    _tempoAudio = null;

    future?.then((rendered) {
      if (rendered == null || state.status != PerformanceStatus.running) return;
      _audioBaseMs = rendered.baseMs;
      _lastAlignMs = _nowMs;
      _audio?.play(
        rendered.wav,
        position: Duration(milliseconds: max(0, (_nowMs - rendered.baseMs).round())),
      );
    });
  }


  // Diferença máxima aceita entre o áudio e o relógio da sessão.
  static const audioToleranceMs = 30;

  // Intervalo entre as conferências do alinhamento.
  static const _alignIntervalMs = 1500;

  // Mantém o áudio do app no relógio da sessão (o mesmo do metrônomo visual
  // e das batidas do dispositivo): corrige o início (relógio local antes da
  // primeira batida), o tempo de partida do player e engasgos de reprodução.
  void _checkAudioAlignment({bool force = false}) {

    final audio = _audio;
    final base = _audioBaseMs;

    if (audio == null || base == null || _aligning) return;

    final before = _nowMs;

    if (!force && before - _lastAlignMs < _alignIntervalMs) return;

    _lastAlignMs = before;
    _aligning = true;

    audio.position().then((position) {

      _aligning = false;

      final active = state.status == PerformanceStatus.countdown ||
          state.status == PerformanceStatus.running;

      if (position == null || !active || _audioBaseMs != base) return;

      // Posição lida entre os dois instantes (o pedido leva alguns ms).
      final expected = (before + _nowMs) / 2 - base;

      if (expected < 0) return;

      if ((position.inMilliseconds - expected).abs() > audioToleranceMs) {
        _audioCorrections++;
        audio.seek(Duration(milliseconds: (_nowMs - base).round()));
      }
    }, onError: (Object _) {
      _aligning = false;
    });
  }


  // Uma nota não tocada vira "Perdeu" depois da janela mais o atraso de
  // entrega. Em vez de um valor fixo (350 ms), usa o maior atraso medido nas
  // últimas notas + margem: com o dispositivo respondendo rápido, o "Perdeu"
  // aparece antes. Se uma nota chegar depois disso, ela ainda substitui a
  // "perdida" (o instante avaliado é o do ataque).
  void _measureNoteLag(int onsetMs) {

    final evaluator = _evaluator;

    if (evaluator == null || _offsetMs == null) return;

    _noteLags.add(max(0, _nowMs - onsetMs));

    if (_noteLags.length > 12) _noteLags.removeAt(0);

    if (_noteLags.length < 3) return;

    evaluator.deliveryLatencyMs = (_noteLags.reduce(max) + 80)
        .clamp(150, evaluator.tolerance.deliveryLatencyMs);
  }


  // -------------------------------------------------------
  // PAUSA / REPETIÇÃO / FIM
  // -------------------------------------------------------

  void _pause() {

    _ticker?.cancel();
    _ticker = null;
    live.clear();
    _events?.cancel();
    _events = null;
    _audio?.stop();

    ref.read(connectionRepositoryProvider).stopSession();
  }


  Future<void> _stopRun() async {

    final wasActive = _ticker != null || _events != null;

    _ticker?.cancel();
    _ticker = null;
    live.clear();
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

    if (evaluator != null) _log?.finish(result);
    _log = null;

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

      // Detalhes para reabrir a execução pelo histórico com a mesma tela
      // do fim da execução.
      notasEsperadas:
          result?.notesExpected,

      notasExtras:
          result?.extraNotes,

      maiorSequencia:
          state.bestStreak,

      compassosPorTrecho:
          ref.read(configurationProvider).measuresPerPhrase,

      trechos:
          result?.phrases,

      resultadoNotas:
          state.feedback,
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


// Áudio gerado e o instante da sessão em que ele começa.
typedef _RenderedAudio = ({double baseMs, Uint8List wav});

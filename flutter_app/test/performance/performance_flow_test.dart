import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_app/features/configuration/presentation/providers/configuration_provider.dart';
import 'package:flutter_app/features/connection/data/datasources/connection_remote_datasource.dart';
import 'package:flutter_app/features/connection/data/datasources/simulated_device_datasource.dart';
import 'package:flutter_app/features/connection/domain/entities/device_event.dart';
import 'package:flutter_app/features/connection/presentation/providers/connection_provider.dart';
import 'package:flutter_app/features/execution_log/domain/services/execution_console_log.dart';
import 'package:flutter_app/features/execution_log/presentation/providers/execution_log_provider.dart';
import 'package:flutter_app/features/performance/data/services/audio_synth.dart';
import 'package:flutter_app/features/performance/data/services/performance_audio.dart';
import 'package:flutter_app/features/performance/domain/entities/performance_state.dart';
import 'package:flutter_app/features/performance/presentation/providers/performance_provider.dart';
import 'package:flutter_app/features/score/domain/entities/musical_score.dart';
import 'package:flutter_app/features/score/domain/entities/note_comparison.dart';
import 'package:flutter_app/features/score/domain/repositories/score_repository.dart';
import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_app/features/score/domain/usecases/get_music_score.dart';
import 'package:flutter_app/features/score/presentation/providers/score_provider.dart';
import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lê as partituras direto do disco (sem rootBundle).
class _FileScoreRepository implements ScoreRepository {
  @override
  Future<MusicalScore> getScore(String fileName) async {
    final file = File('assets/partituras/$fileName');
    if (!file.existsSync()) throw Exception('não encontrada: $fileName');
    return MusicXmlParser().parse(file.readAsStringSync());
  }
}

// Áudio silencioso (sem plugin nativo nos testes).
class _SilentAudio extends PerformanceAudio {
  int played = 0;
  int preloaded = 0;

  @override
  Future<Uint8List> render(SynthRequest request) async => Uint8List(0);

  @override
  Future<void> preload(Uint8List wav) async => preloaded++;

  @override
  Future<bool> play(Uint8List wav, {Duration position = Duration.zero}) async {
    played++;
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<Duration?> position() async => null;

  @override
  Future<void> seek(Duration position) async {}
}

// Registra a geração, a pré-carga e a reprodução do áudio e simula a
// posição do player (que pode começar `lagMs` atrasado).
class _RecordingAudio extends _SilentAudio {
  final int lagMs;

  _RecordingAudio({this.lagMs = 0});

  Uint8List? _ready;
  int playedPreloaded = 0;
  final requests = <SynthRequest>[];
  final playedRequests = <SynthRequest>[];
  final _byWav = <Uint8List, SynthRequest>{};
  final seeks = <Duration>[];
  Stopwatch? _since;
  Duration _from = Duration.zero;

  @override
  Future<Uint8List> render(SynthRequest request) async {
    requests.add(request);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final wav = Uint8List(1);
    _byWav[wav] = request;
    return wav;
  }

  @override
  Future<Duration?> position() async {
    final since = _since;
    if (since == null) return null;
    return _from + since.elapsed;
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _from = position;
    _since = Stopwatch()..start();
  }

  @override
  Future<void> preload(Uint8List wav) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _ready = wav;
    preloaded++;
  }

  @override
  Future<bool> play(Uint8List wav, {Duration position = Duration.zero}) async {
    if (identical(wav, _ready)) playedPreloaded++;
    _ready = null;
    played++;
    final request = _byWav[wav];
    if (request != null) playedRequests.add(request);
    // O player começa `lagMs` depois (tempo de partida / saída de áudio).
    _from = position - Duration(milliseconds: lagMs);
    _since = Stopwatch()..start();
    return true;
  }
}

// Confere cada clique do áudio do app com as batidas do dispositivo:
// mesmo instante (±2 ms) e mesmo tempo forte.
List<String> _clickMismatches(
  SynthRequest request,
  double baseMs,
  List<BeatEvent> beats,
  int beatsPerBar,
) {
  final problems = <String>[];
  for (final beat in beats) {
    final t = beat.timeMs - baseMs;
    if (t < 0 || t >= request.totalMs - 1) continue;
    final click = request.clicks.where((c) => (c.timeMs - t).abs() <= 2).firstOrNull;
    if (click == null) {
      problems.add('sem clique na batida de ${beat.timeMs} ms');
    } else if (click.accent != (beat.beatInBar == 0)) {
      problems.add('tempo forte trocado em ${beat.timeMs} ms');
    }
  }
  return problems;
}

const _song = Song(
  id: 'ode_a_alegria',
  titulo: 'Ode à alegria',
  compositor: 'Beethoven',
  nivelDificuldade: 'fácil',
  bpmPadrao: 240,
  arquivoMidi: 'ode_a_alegria.mid',
);

ProviderContainer _container(
  ConnectionRemoteDataSource simulator, {
  List<String>? log,
  PerformanceAudio? audio,
}) {
  return ProviderContainer(
    overrides: [
      executionConsoleLogProvider.overrideWithValue(ExecutionConsoleLog((line) => log?.add(line))),
      simulatedDeviceDataSourceProvider.overrideWithValue(simulator),
      getMusicScoreProvider.overrideWithValue(GetMusicScore(_FileScoreRepository())),
      performanceAudioProvider.overrideWithValue(audio ?? _SilentAudio()),
    ],
  );
}

Future<PerformanceState> _waitFor(
  ProviderContainer container,
  bool Function(PerformanceState) condition, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final state = container.read(performanceProvider);
    if (condition(state)) return state;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('estado esperado não alcançado: ${container.read(performanceProvider).status}');
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'config.metronomeSound': false,
      'config.guideAudio': false,
    });
  });

  test('aluno virtual toca a música inteira e recebe a avaliação', () async {
    final log = <String>[];
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 25, seed: 1),
      log: log,
    );
    addTearDown(container.dispose);

    // Garante que as configurações foram carregadas.
    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await container.read(connectionProvider.notifier).useSimulator(), isTrue);

    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    final ready = container.read(performanceProvider);
    expect(ready.status, PerformanceStatus.ready);
    expect(ready.structure!.phrases, hasLength(4));

    // Fluidez: a tela só é notificada quando algo visível muda (antes, a
    // cada 30 ms); o cursor e o metrônomo visual vêm do relógio ao vivo.
    var updates = 0;
    container.listen(performanceProvider, (_, _) => updates++);
    final beatMismatches = <String>[];
    var beats = 0;
    final beatsPerBar = ready.structure!.score.beatsPerBar;
    final watch = Stopwatch()..start();

    await notifier.start();
    expect(container.read(performanceProvider).status, PerformanceStatus.countdown);
    final beatSub = container.read(connectionRepositoryProvider).events.listen((event) {
      if (event is! BeatEvent) return;
      beats++;
      // Batida local no instante em que a batida do dispositivo chega (o
      // pacote pode chegar alguns ms depois: vale a batida corrente ou a
      // anterior). Assinado depois do início: o app já processou a batida
      // (alinhamento do relógio). No primeiro compasso o relógio ainda está
      // sendo alinhado.
      notifier.sampleLiveClock();
      final live = notifier.live.metronomeBeat.value;
      if (live < 0 || beats <= beatsPerBar) return;
      final inBar = live % beatsPerBar;
      final previous = (live - 1) % beatsPerBar;
      if (inBar != event.beatInBar && previous != event.beatInBar) {
        beatMismatches.add('dispositivo ${event.beatInBar} x app $inBar (t=${event.timeMs} ms)');
      }
    });
    addTearDown(beatSub.cancel);

    await _waitFor(container, (s) => s.status == PerformanceStatus.running);
    expect(notifier.live.isRunning, isTrue);
    final finished = await _waitFor(container, (s) => s.status == PerformanceStatus.finished);
    final seconds = watch.elapsedMilliseconds / 1000;
    // ignore: avoid_print
    print('${(updates / seconds).toStringAsFixed(1)} atualizações de estado por segundo; '
        '$beats batidas do dispositivo');
    expect(updates / seconds, lessThan(12));
    expect(beats, greaterThan(20));
    expect(beatMismatches, isEmpty);
    expect(notifier.live.isRunning, isFalse);

    final result = finished.result!;
    // ignore: avoid_print
    print('altura ${result.pitchAccuracy.toStringAsFixed(1)}% · ritmo '
        '${result.rhythmAccuracy.toStringAsFixed(1)}% · geral ${result.overall.toStringAsFixed(1)}% · '
        '${result.notesCorrect}/${result.notesExpected} corretas, ${result.extraNotes} extras');

    expect(result.completed, isTrue);
    expect(result.phrases, hasLength(4));
    expect(result.pitchAccuracy, greaterThan(95));
    expect(result.overall, greaterThan(80));
    expect(finished.feedback, isNotEmpty);
    // HUD: sequência de acertos, selo da última nota e nota de cada trecho.
    expect(finished.bestStreak, greaterThan(10));
    expect(finished.judgement, isNotNull);
    expect(finished.phraseScores.keys, containsAll([0, 1, 2, 3]));

    // Console: notas esperadas e captadas com nome e figura.
    expect(log.first, startsWith('[Execução] Início'));
    // Som do app: contagem do modo demonstração tocando.
    expect(log.where((l) => l.startsWith('[Áudio   ]')).single, endsWith('→ tocando'));
    expect(log.where((l) => l.startsWith('[Esperado]')), hasLength(result.notesExpected));
    expect(log.any((l) => l.startsWith('[Captado ]') && l.contains('Perfeito!')), isTrue);
    expect(log.any((l) => l.contains('semínima') || l.contains('colcheia')), isTrue);
    expect(log.where((l) => l.startsWith('[Trecho  ]')), hasLength(4));
    expect(log.last, startsWith('[Execução] Concluída'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Dispositivo real: cada nota chega ao app ~300 ms depois do ataque
  // (confirmação da altura + Wi-Fi/WebSocket). As notas certas, no tempo
  // certo, não podem virar "perdidas" + "extras".
  test('notas que chegam atrasadas pela rede continuam corretas', () async {
    final container = _container(
      SimulatedDeviceDataSource(
        wrongNoteRate: 0,
        missedNoteRate: 0,
        timingJitterMs: 25,
        noteDeliveryDelayMs: 300,
        seed: 4,
      ),
    );
    addTearDown(container.dispose);
    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    await notifier.start();

    final finished = await _waitFor(container, (s) => s.status == PerformanceStatus.finished);
    final result = finished.result!;
    expect(result.completed, isTrue);
    expect(result.extraNotes, 0);
    expect(result.pitchAccuracy, greaterThan(95));
    expect(result.overall, greaterThan(80));
    // Atraso medido alto: o "Perdeu" continua esperando o máximo.
    expect(notifier.deliveryLatencyMs, 350);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Dispositivo e rede rápidos: uma nota não tocada vira "Perdeu" mais cedo
  // (atraso medido + margem, em vez de 350 ms fixos), sem marcar como
  // perdida nenhuma nota que foi tocada.
  test('"Perdeu" aparece mais cedo com rede rápida e só em notas não tocadas', () async {
    final container = _container(
      SimulatedDeviceDataSource(
        wrongNoteRate: 0,
        missedNoteRate: 0.15,
        timingJitterMs: 25,
        noteDeliveryDelayMs: 40,
        seed: 6,
      ),
    );
    addTearDown(container.dispose);
    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);

    final flashedMissed = <int>{};
    container.listen<PerformanceState>(performanceProvider, (previous, next) {
      final judgement = next.judgement;
      if (judgement != null &&
          judgement.serial != previous?.judgement?.serial &&
          judgement.feedback == NoteFeedback.missed &&
          judgement.noteId != null) {
        flashedMissed.add(judgement.noteId!);
      }
    });

    await notifier.start();
    final finished = await _waitFor(container, (s) => s.status == PerformanceStatus.finished);

    expect(notifier.deliveryLatencyMs, lessThanOrEqualTo(200));
    expect(flashedMissed, isNotEmpty);
    // Toda nota que apareceu como "Perdeu" realmente não foi tocada.
    for (final id in flashedMissed) {
      expect(finished.feedback[id], NoteFeedback.missed, reason: 'nota $id');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Lógica no ritmo da tela: com a tela pedindo um quadro a cada ~5 ms, a
  // passagem da contagem para a música é vista no quadro em que acontece
  // (antes, só no próximo ciclo de 30 ms).
  test('início da música detectado no quadro em que acontece', () async {
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 25, seed: 7),
    );
    addTearDown(container.dispose);
    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    final firstBeat = container.read(performanceProvider).structure!.phrases.first.startBeat;

    double? cursorAtStart;
    container.listen<PerformanceState>(performanceProvider, (previous, next) {
      if (previous?.status == PerformanceStatus.countdown && next.status == PerformanceStatus.running) {
        notifier.sampleLiveClock();
        cursorAtStart = notifier.live.cursorBeat.value;
      }
    });

    await notifier.start();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (cursorAtStart == null && DateTime.now().isBefore(deadline)) {
      notifier.onFrame();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await notifier.stop();

    // 240 BPM: 1 semínima = 250 ms; 0,08 semínima = 20 ms.
    expect(cursorAtStart, isNotNull);
    expect(cursorAtStart! - firstBeat, lessThan(0.08));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('frase abaixo de 50% interrompe a execução e permite repetir', () async {
    final container = _container(
      SimulatedDeviceDataSource(missedNoteRate: 1, seed: 2),
    );
    addTearDown(container.dispose);

    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    await notifier.start();

    final failed = await _waitFor(container, (s) => s.status == PerformanceStatus.phraseFailed);
    expect(failed.lastPhrase!.phraseIndex, 0);
    expect(failed.lastPhrase!.score, lessThan(50));

    // Repetir mais devagar reinicia o trecho com contagem de entrada.
    await notifier.retryPhrase(slower: true);
    final retry = container.read(performanceProvider);
    expect(retry.status, PerformanceStatus.countdown);
    expect(retry.bpm, 216);

    await notifier.stop();
    final stopped = await _waitFor(container, (s) => s.status == PerformanceStatus.finished);
    expect(stopped.result!.completed, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Metrônomo sonoro sem atraso: contagem, metrônomo e música guia em um
  // único áudio, gerado e carregado antes do INICIAR. A música começa na
  // amostra exata em que a contagem termina (antes, a troca de arquivo na
  // passagem da contagem para a música atrasava o primeiro tempo).
  Future<(_RecordingAudio, List<BeatEvent>, PerformanceNotifier, int)> runWithAudio({
    int lagMs = 0,
    int seed = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'config.metronomeSound': true,
      'config.guideAudio': true,
    });
    final audio = _RecordingAudio(lagMs: lagMs);
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 25, seed: seed),
      audio: audio,
    );
    addTearDown(container.dispose);

    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(audio.preloaded, 1);                                     // pronto antes do INICIAR

    final beats = <BeatEvent>[];
    final sub = container.read(connectionRepositoryProvider).events.listen((event) {
      if (event is BeatEvent) beats.add(event);
    });
    addTearDown(sub.cancel);

    await notifier.start();
    await _waitFor(container, (s) => s.status == PerformanceStatus.finished);
    final beatsPerBar = container.read(performanceProvider).structure!.score.beatsPerBar;
    return (audio, beats, notifier, beatsPerBar);
  }

  test('metrônomo sonoro: um único áudio, cliques nas batidas do dispositivo', () async {
    final (audio, beats, notifier, beatsPerBar) = await runWithAudio();

    // Um só arquivo do início ao fim, já carregado quando começou a tocar.
    expect(audio.played, 1);
    expect(audio.playedPreloaded, 1);
    final session = audio.playedRequests.single;
    expect(session.notes, isNotEmpty);                              // música guia
    // Contagem e música no mesmo arquivo: cliques em todas as batidas.
    expect(beats.length, greaterThan(70));
    expect(_clickMismatches(session, 0, beats, beatsPerBar), isEmpty);
    // Player começando no tempo: nenhuma correção de alinhamento.
    expect(notifier.audioCorrections, 0);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Player que começa atrasado (tempo de partida no celular ou no navegador):
  // o áudio é realinhado ao relógio da sessão, sem ficar corrigindo sem parar.
  test('áudio que começa 120 ms atrasado é realinhado às batidas', () async {
    final (audio, _, notifier, _) = await runWithAudio(lagMs: 120, seed: 2);

    expect(audio.played, 1);
    expect(notifier.audioCorrections, inInclusiveRange(1, 3));
    expect(audio.seeks, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ritmo irregular reduz o BPM automaticamente (RU12)', () async {
    SharedPreferences.setMockInitialValues({
      'config.metronomeSound': true,
      'config.autoTempo': true,
    });
    // Com o metrônomo sonoro: o áudio regenerado no novo andamento (a única
    // troca de arquivo da execução) é carregado antes de tocar e seus
    // cliques caem nas batidas do dispositivo no novo BPM.
    final audio = _RecordingAudio();
    final beats = <BeatEvent>[];
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 170, seed: 3),
      audio: audio,
    );
    addTearDown(container.dispose);

    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(configurationProvider).autoTempo, isTrue);

    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    final sub = container.read(connectionRepositoryProvider).events.listen((event) {
      if (event is BeatEvent) beats.add(event);
    });
    addTearDown(sub.cancel);
    await notifier.start();

    var minBpm = 240;
    String? messageWhileRunning;
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(deadline)) {
      final s = container.read(performanceProvider);
      if (s.bpm < minBpm) minBpm = s.bpm;
      // Nenhum aviso sobre a partitura durante a execução (o percentual de
      // cada trecho cobria o início do trecho seguinte).
      if (s.status == PerformanceStatus.running && s.message != null) {
        messageWhileRunning = s.message;
      }
      if (s.status == PerformanceStatus.finished || s.status == PerformanceStatus.phraseFailed) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // ignore: avoid_print
    print('menor BPM: $minBpm');
    expect(messageWhileRunning, isNull);
    // RU12: a redução aparece no indicador de andamento.
    expect(minBpm, lessThan(240));
    // Áudio da sessão + um arquivo por mudança de andamento já aplicada.
    expect(audio.played, greaterThanOrEqualTo(2));
    expect(audio.playedPreloaded, audio.played);
    final tempoAudio = audio.playedRequests[1];
    final changed = beats.firstWhere((b) => b.bpm < 240);
    final beatsPerBar = container.read(performanceProvider).structure!.score.beatsPerBar;
    final afterChange = beats.where((b) => b.timeMs >= changed.timeMs).toList();
    expect(_clickMismatches(tempoAudio, changed.timeMs.toDouble(), afterChange, beatsPerBar), isEmpty);
    expect(tempoAudio.clicks.first.timeMs, 0);                      // começa na batida da troca
  }, timeout: const Timeout(Duration(seconds: 60)));
}

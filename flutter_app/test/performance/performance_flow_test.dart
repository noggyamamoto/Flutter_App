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
  Future<void> play(Uint8List wav, {Duration position = Duration.zero}) async => played++;

  @override
  Future<void> stop() async {}
}

// Registra a ordem de geração, pré-carga e reprodução do áudio.
class _RecordingAudio extends _SilentAudio {
  Uint8List? _ready;
  int playedPreloaded = 0;

  @override
  Future<Uint8List> render(SynthRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 15));
    return Uint8List(1);
  }

  @override
  Future<void> preload(Uint8List wav) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _ready = wav;
    preloaded++;
  }

  @override
  Future<void> play(Uint8List wav, {Duration position = Duration.zero}) async {
    if (identical(wav, _ready)) playedPreloaded++;
    _ready = null;
    played++;
  }
}

const _song = Song(
  id: 'sinfonia',
  titulo: 'Sinfonia Coral',
  compositor: 'Beethoven',
  nivelDificuldade: 'fácil',
  bpmPadrao: 240,
  arquivoMidi: 'sinfonia_coral_melodia_16_compassos.mid',
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
    final beatSub = container.read(connectionRepositoryProvider).events.listen((event) {
      if (event is! BeatEvent) return;
      beats++;
      // Batida local no instante da batida do dispositivo (o pacote pode
      // chegar alguns ms depois: vale a batida corrente ou a anterior). No
      // primeiro compasso o relógio ainda está sendo alinhado às batidas.
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
    final watch = Stopwatch()..start();

    await notifier.start();
    expect(container.read(performanceProvider).status, PerformanceStatus.countdown);

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
  }, timeout: const Timeout(Duration(seconds: 60)));

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

  // Metrônomo sonoro sem atraso: a contagem é gerada e carregada no player
  // antes do INICIAR e cada trecho é carregado no outro player enquanto o
  // anterior toca (começa na hora, sem preparar o player na troca).
  test('metrônomo sonoro: contagem e trechos já carregados antes de tocar', () async {
    SharedPreferences.setMockInitialValues({
      'config.metronomeSound': true,
      'config.guideAudio': true,
    });
    final audio = _RecordingAudio();
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 25, seed: 1),
      audio: audio,
    );
    addTearDown(container.dispose);

    container.read(configurationProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(connectionProvider.notifier).useSimulator();
    final notifier = container.read(performanceProvider.notifier);
    await notifier.loadSong(_song);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(audio.preloaded, 1);                                     // contagem pronta

    await notifier.start();
    await _waitFor(container, (s) => s.status == PerformanceStatus.finished);

    // Contagem + 4 trechos, todos já carregados quando começaram a tocar.
    expect(audio.played, 5);
    expect(audio.playedPreloaded, 5);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ritmo irregular reduz o BPM automaticamente (RU12)', () async {
    SharedPreferences.setMockInitialValues({
      'config.metronomeSound': true,
      'config.autoTempo': true,
    });
    // Com o metrônomo sonoro: o trecho regenerado no novo andamento também
    // é carregado antes de tocar.
    final audio = _RecordingAudio();
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
    expect(audio.played, greaterThan(2));
    expect(audio.playedPreloaded, audio.played);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

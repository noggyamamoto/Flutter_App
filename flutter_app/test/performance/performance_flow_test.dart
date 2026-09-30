import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_app/features/configuration/presentation/providers/configuration_provider.dart';
import 'package:flutter_app/features/connection/data/datasources/connection_remote_datasource.dart';
import 'package:flutter_app/features/connection/data/datasources/simulated_device_datasource.dart';
import 'package:flutter_app/features/connection/presentation/providers/connection_provider.dart';
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
    return MusicXmlParser().parse(File('assets/partituras/$fileName').readAsStringSync());
  }
}

// Áudio silencioso (sem plugin nativo nos testes).
class _SilentAudio extends PerformanceAudio {
  int played = 0;

  @override
  Future<Uint8List> render(SynthRequest request) async => Uint8List(0);

  @override
  Future<void> play(Uint8List wav) async => played++;

  @override
  Future<void> stop() async {}
}

const _song = Song(
  id: 'sinfonia',
  titulo: 'Sinfonia Coral',
  compositor: 'Beethoven',
  nivelDificuldade: 'fácil',
  bpmPadrao: 240,
  arquivoMidi: 'sinfonia_coral_melodia_16_compassos.mid',
);

ProviderContainer _container(ConnectionRemoteDataSource simulator) {
  return ProviderContainer(
    overrides: [
      simulatedDeviceDataSourceProvider.overrideWithValue(simulator),
      getMusicScoreProvider.overrideWithValue(GetMusicScore(_FileScoreRepository())),
      performanceAudioProvider.overrideWithValue(_SilentAudio()),
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
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 25, seed: 1),
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

    await notifier.start();
    expect(container.read(performanceProvider).status, PerformanceStatus.countdown);

    await _waitFor(container, (s) => s.status == PerformanceStatus.running);
    final finished = await _waitFor(container, (s) => s.status == PerformanceStatus.finished);

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

  test('ritmo irregular reduz o BPM automaticamente (RU12)', () async {
    SharedPreferences.setMockInitialValues({
      'config.metronomeSound': false,
      'config.autoTempo': true,
    });
    final container = _container(
      SimulatedDeviceDataSource(wrongNoteRate: 0, missedNoteRate: 0, timingJitterMs: 170, seed: 3),
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
    String? message;
    final deadline = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(deadline)) {
      final s = container.read(performanceProvider);
      if (s.bpm < minBpm) minBpm = s.bpm;
      if (s.message != null && s.message!.contains('reduzido')) message = s.message;
      if (s.status == PerformanceStatus.finished || s.status == PerformanceStatus.phraseFailed) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // ignore: avoid_print
    print('mensagem: $message | menor BPM: $minBpm');
    expect(message, isNotNull);
    expect(minBpm, lessThan(240));
  }, timeout: const Timeout(Duration(seconds: 60)));
}

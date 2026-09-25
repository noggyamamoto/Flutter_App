import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../songs/domain/entities/song.dart';

import '../../data/datasources/midi_local_datasource.dart';
import '../../data/datasources/midi_local_datasource_impl.dart';
import '../../data/repositories/midi_repository_impl.dart';

import '../../domain/entities/midi_score.dart';
import '../../domain/entities/performance_state.dart';
import '../../domain/repositories/midi_repository.dart';
import '../../domain/services/midi_parser.dart';
import '../../domain/usecases/get_midi_file.dart';

final midiDataSourceProvider =
    Provider<MidiLocalDataSource>((ref) {
  return MidiLocalDataSourceImpl();
});

final midiRepositoryProvider =
    Provider<MidiRepository>((ref) {
  final dataSource =
      ref.watch(midiDataSourceProvider);

  return MidiRepositoryImpl(dataSource);
});

final getMidiFileProvider =
    Provider<GetMidiFile>((ref) {
  final repository =
      ref.watch(midiRepositoryProvider);

  return GetMidiFile(repository);
});

final midiParserProvider =
    Provider<MidiParser>((ref) {
  return MidiParser();
});

class PerformanceNotifier
    extends Notifier<PerformanceState> {
  Timer? _timer;

  @override
  PerformanceState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });

    return const PerformanceState(
      status: PerformanceStatus.initial,
    );
  }

  Future<void> loadSong(Song song) async {
    _timer?.cancel();

    state = const PerformanceState(
      status: PerformanceStatus.loading,
    );

    try {
      final getMidiFile =
          ref.read(getMidiFileProvider);

      final parser =
          ref.read(midiParserProvider);

      final midiPath =
          'assets/midi/${song.arquivoMidi}';

      final bytes =
          await getMidiFile(midiPath);

      final MidiScore score =
          parser.parse(
        bytes,
        defaultBpm: song.bpmPadrao,
      );

      state = PerformanceState(
        status: PerformanceStatus.ready,
        score: score,
      );
    } catch (e) {
      state = PerformanceState(
        status: PerformanceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void startCountdown() {
    state = state.copyWith(
      status: PerformanceStatus.countdown,
    );
  }

  void startPerformance() {
    state = state.copyWith(
      status: PerformanceStatus.running,
      elapsed: Duration.zero,
    );

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (state.status !=
            PerformanceStatus.running) {
          return;
        }

        state = state.copyWith(
          elapsed: state.elapsed +
              const Duration(seconds: 1),
        );
      },
    );
  }

  void updatePrecision(
    double precision,
  ) {
    state = state.copyWith(
      precision: precision,
    );
  }

  void updateNotesPlayed(
    int notesPlayed,
  ) {
    state = state.copyWith(
      notesPlayed: notesPlayed,
    );
  }

  void finishPerformance() {
    _timer?.cancel();

    state = state.copyWith(
      status: PerformanceStatus.finished,
    );
  }

  void reset() {
    _timer?.cancel();

    state = const PerformanceState(
      status: PerformanceStatus.initial,
    );
  }
}

final performanceProvider =
    NotifierProvider<
        PerformanceNotifier,
        PerformanceState>(
  PerformanceNotifier.new,
);
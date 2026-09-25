import 'midi_score.dart';

enum PerformanceStatus {
  initial,
  loading,
  ready,
  countdown,
  running,
  finished,
  error,
}

class PerformanceState {
  final PerformanceStatus status;
  final MidiScore? score;
  final double precision;
  final int notesPlayed;
  final Duration elapsed;
  final String? errorMessage;

  const PerformanceState({
    required this.status,
    this.score,
    this.precision = 0,
    this.notesPlayed = 0,
    this.elapsed = Duration.zero,
    this.errorMessage,
  });

  PerformanceState copyWith({
    PerformanceStatus? status,
    MidiScore? score,
    double? precision,
    int? notesPlayed,
    Duration? elapsed,
    String? errorMessage,
  }) {
    return PerformanceState(
      status: status ?? this.status,
      score: score ?? this.score,
      precision: precision ?? this.precision,
      notesPlayed: notesPlayed ?? this.notesPlayed,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
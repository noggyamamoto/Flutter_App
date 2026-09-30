import 'note_comparison.dart';

// Avaliação de uma frase musical (RFA07).
class PhraseResult {
  final int phraseIndex;

  // Percentuais de 0 a 100.
  final double pitchAccuracy;
  final double rhythmAccuracy;
  final double score;

  final int notesExpected;
  final int notesCorrect;
  final int notesMissed;
  final int extraNotes;

  // Desvio-padrão do erro de ataque (ms).
  final double timingDeviationMs;

  // Frase aprovada, porém com instabilidade (RFA09).
  final bool unstable;

  const PhraseResult({
    required this.phraseIndex,
    required this.pitchAccuracy,
    required this.rhythmAccuracy,
    required this.score,
    required this.notesExpected,
    required this.notesCorrect,
    required this.notesMissed,
    required this.extraNotes,
    required this.timingDeviationMs,
    required this.unstable,
  });

  // Abaixo de 50% a execução é interrompida (RFA08).
  bool get failed => score < 50;
}

// Pontuação macro da execução (RU13 / RFA10).
class ScoreResult {
  // Precisão de altura (Hz) e de duração/tempo, de 0 a 100.
  final double pitchAccuracy;
  final double rhythmAccuracy;

  // Pontuação geral de 0 a 100.
  final double overall;

  final int notesExpected;
  final int notesCorrect;
  final int notesPlayed;
  final int extraNotes;

  // Música tocada até o fim.
  final bool completed;

  final List<NoteComparison> comparisons;
  final List<PhraseResult> phrases;

  const ScoreResult({
    required this.pitchAccuracy,
    required this.rhythmAccuracy,
    required this.overall,
    required this.notesExpected,
    required this.notesCorrect,
    required this.notesPlayed,
    required this.extraNotes,
    required this.completed,
    required this.comparisons,
    required this.phrases,
  });

  static const empty = ScoreResult(
    pitchAccuracy: 0,
    rhythmAccuracy: 0,
    overall: 0,
    notesExpected: 0,
    notesCorrect: 0,
    notesPlayed: 0,
    extraNotes: 0,
    completed: false,
    comparisons: [],
    phrases: [],
  );
}

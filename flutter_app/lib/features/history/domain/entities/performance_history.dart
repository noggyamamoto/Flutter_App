import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';

class PerformanceHistory {
  // ID do documento da execução no Firestore.
  final String executionId;

  // ID da partitura executada.
  final String songId;

  // Data e hora em que a execução aconteceu.
  final DateTime date;

  // Pontuação final obtida na execução.
  final double score;

  // BPM usado no início da execução.
  final int bpm;

  // Status da execução.
  final String status;

  // Precisão de altura e de ritmo (0 a 100), quando disponíveis.
  final double? pitchScore;
  final double? rhythmScore;

  // BPM ao final da execução (pode ter sido reduzido).
  final int? finalBpm;

  // Contagem de notas (execuções antigas não possuem).
  final int? notesPlayed;
  final int? notesCorrect;
  final int? notesExpected;
  final int? extraNotes;

  // Maior sequência de acertos.
  final int? bestStreak;

  // Compassos por trecho usados na execução (para remontar os trechos).
  final int? measuresPerPhrase;

  // Avaliação de cada trecho tocado.
  final List<PhraseResult> phrases;

  // Resultado de cada nota da partitura (id da nota -> resultado): permite
  // reabrir a execução com as notas coloridas, como no fim da execução.
  final Map<int, NoteFeedback> noteFeedback;

  const PerformanceHistory({
    required this.executionId,
    required this.songId,
    required this.date,
    required this.score,
    required this.bpm,
    required this.status,
    this.pitchScore,
    this.rhythmScore,
    this.finalBpm,
    this.notesPlayed,
    this.notesCorrect,
    this.notesExpected,
    this.extraNotes,
    this.bestStreak,
    this.measuresPerPhrase,
    this.phrases = const [],
    this.noteFeedback = const {},
  });

  // Música tocada até o fim.
  bool get completed => status == 'concluida';

  // Execução salva com o resultado nota a nota.
  bool get hasNoteDetails => noteFeedback.isNotEmpty;

  // Avaliação no formato do fim da execução (altura, ritmo e trechos).
  // Execuções antigas, sem altura e ritmo salvos, não possuem.
  ScoreResult? get scoreResult {
    final pitch = pitchScore;
    final rhythm = rhythmScore;
    if (pitch == null || rhythm == null) return null;
    return ScoreResult(
      pitchAccuracy: pitch,
      rhythmAccuracy: rhythm,
      overall: score,
      notesExpected: notesExpected ?? 0,
      notesCorrect: notesCorrect ?? 0,
      notesPlayed: notesPlayed ?? 0,
      extraNotes: extraNotes ?? 0,
      completed: completed,
      comparisons: const [],
      phrases: phrases,
    );
  }
}

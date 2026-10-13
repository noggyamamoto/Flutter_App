import '../../../score/domain/entities/expected_note.dart';
import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';
import '../../../score/domain/services/score_analyzer.dart';

// Avaliação instantânea da última nota (selo exibido sobre a partitura,
// como nos apps de prática musical: "Perfeito!", "Atrasado"...).
class NoteJudgement {
  // Número sequencial (cada nova avaliação reinicia a animação).
  final int serial;

  // Nota da partitura onde o selo é exibido (null = nota extra).
  final int? noteId;

  final NoteFeedback feedback;

  // Texto curto exibido ao aluno.
  final String label;

  const NoteJudgement({
    required this.serial,
    required this.noteId,
    required this.feedback,
    required this.label,
  });

  // Gera o texto a partir da comparação com o gabarito.
  static String labelFor(NoteComparison? comparison) {
    if (comparison == null) return 'Nota extra';
    final timing = comparison.onsetErrorMs;
    switch (comparison.feedback) {
      case NoteFeedback.correct:
        return 'Perfeito!';
      case NoteFeedback.approximate:
        if (comparison.pitchScore >= 1 && timing != null) {
          return timing > 0 ? 'Atrasado' : 'Adiantado';
        }
        return 'Quase!';
      case NoteFeedback.incorrect:
        return 'Nota errada';
      case NoteFeedback.missed:
        return 'Perdeu';
      case NoteFeedback.pending:
        return '';
    }
  }
}

enum PerformanceStatus {
  initial,
  loading,
  ready,
  countdown,
  running,

  // Frase abaixo de 50%: execução travada aguardando o aluno (RFA08).
  phraseFailed,

  finished,
  error,
}

class PerformanceState {
  final PerformanceStatus status;

  // Partitura, frases e melodia avaliada.
  final ScoreStructure? structure;

  // Frase exibida na tela.
  final int viewPhrase;

  // Andamento atual e andamento inicial (semínimas por minuto).
  final int bpm;
  final int initialBpm;

  // Feedback de cada nota da partitura (id -> resultado) – RFA06.
  final Map<int, NoteFeedback> feedback;

  // Posição atual da execução (semínimas).
  final double? cursorBeat;

  // Contagem de entrada: tempo (1..n) e compasso (1..2) iniciais. Durante a
  // contagem a tela usa o relógio ao vivo (PerformanceLiveClock).
  final int countInBeat;
  final int countInBar;

  // Metrônomo visual: tempo atual no compasso. Durante a execução a tela
  // usa o relógio ao vivo (PerformanceLiveClock); este valor é o exibido
  // sem ele (ex.: telas de teste).
  final int beatInBar;

  // Precisão parcial (0 a 100) e notas tocadas.
  final double precision;
  final int notesPlayed;

  // Tempo desde o início da música exibido sem o relógio ao vivo.
  final Duration elapsed;

  // Última frase avaliada.
  final PhraseResult? lastPhrase;

  // Sugestão de redução de BPM (RFA09) ou null.
  final int? suggestedBpm;

  // Mensagem temporária exibida na tela.
  final String? message;

  // Última nota tocada e seu resultado (exibição ao vivo).
  final int? lastPlayedMidi;
  final NoteFeedback? lastFeedback;

  // Resultado final.
  final ScoreResult? result;

  // Sequência atual de acertos e a maior sequência da execução.
  final int streak;
  final int bestStreak;

  // Última avaliação instantânea (selo sobre a nota).
  final NoteJudgement? judgement;

  // Pontuação (0 a 100) de cada trecho já avaliado.
  final Map<int, double> phraseScores;

  final String? errorMessage;

  const PerformanceState({
    required this.status,
    this.structure,
    this.viewPhrase = 0,
    this.bpm = 0,
    this.initialBpm = 0,
    this.feedback = const {},
    this.cursorBeat,
    this.countInBeat = 0,
    this.countInBar = 0,
    this.beatInBar = 0,
    this.precision = 0,
    this.notesPlayed = 0,
    this.elapsed = Duration.zero,
    this.lastPhrase,
    this.suggestedBpm,
    this.message,
    this.lastPlayedMidi,
    this.lastFeedback,
    this.result,
    this.errorMessage,
    this.streak = 0,
    this.bestStreak = 0,
    this.judgement,
    this.phraseScores = const {},
  });

  // Próxima nota esperada (ainda sem avaliação) a partir do cursor.
  ExpectedNote? get nextExpectedNote {
    final structure = this.structure;
    if (structure == null || structure.phrases.isEmpty) return null;
    final cursor = cursorBeat ?? structure.phrases[viewPhrase].startBeat;
    for (final note in structure.expectedNotes) {
      if (note.phraseIndex < viewPhrase) continue;
      if (note.scoreNoteIds.any(feedback.containsKey)) continue;
      if (note.endBeat <= cursor) continue;
      return note;
    }
    return null;
  }

  PerformanceState copyWith({
    PerformanceStatus? status,
    ScoreStructure? structure,
    int? viewPhrase,
    int? bpm,
    int? initialBpm,
    Map<int, NoteFeedback>? feedback,
    double? cursorBeat,
    bool clearCursor = false,
    int? countInBeat,
    int? countInBar,
    int? beatInBar,
    double? precision,
    int? notesPlayed,
    Duration? elapsed,
    PhraseResult? lastPhrase,
    int? suggestedBpm,
    bool clearSuggestion = false,
    String? message,
    bool clearMessage = false,
    int? lastPlayedMidi,
    NoteFeedback? lastFeedback,
    ScoreResult? result,
    String? errorMessage,
    int? streak,
    int? bestStreak,
    NoteJudgement? judgement,
    bool clearJudgement = false,
    Map<int, double>? phraseScores,
  }) {
    return PerformanceState(
      status: status ?? this.status,
      structure: structure ?? this.structure,
      viewPhrase: viewPhrase ?? this.viewPhrase,
      bpm: bpm ?? this.bpm,
      initialBpm: initialBpm ?? this.initialBpm,
      feedback: feedback ?? this.feedback,
      cursorBeat: clearCursor ? null : (cursorBeat ?? this.cursorBeat),
      countInBeat: countInBeat ?? this.countInBeat,
      countInBar: countInBar ?? this.countInBar,
      beatInBar: beatInBar ?? this.beatInBar,
      precision: precision ?? this.precision,
      notesPlayed: notesPlayed ?? this.notesPlayed,
      elapsed: elapsed ?? this.elapsed,
      lastPhrase: lastPhrase ?? this.lastPhrase,
      suggestedBpm: clearSuggestion ? null : (suggestedBpm ?? this.suggestedBpm),
      message: clearMessage ? null : (message ?? this.message),
      lastPlayedMidi: lastPlayedMidi ?? this.lastPlayedMidi,
      lastFeedback: lastFeedback ?? this.lastFeedback,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      judgement: clearJudgement ? null : (judgement ?? this.judgement),
      phraseScores: phraseScores ?? this.phraseScores,
    );
  }
}

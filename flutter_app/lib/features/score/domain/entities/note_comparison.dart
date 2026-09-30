import 'expected_note.dart';

// Resultado da comparação de uma nota esperada (RFA06).
enum NoteFeedback {
  // Ainda não chegou a vez da nota.
  pending,

  // Altura e tempo corretos (verde).
  correct,

  // Semitom/oitava de diferença ou fora do tempo (laranja).
  approximate,

  // Nota errada (vermelho).
  incorrect,

  // Nota não tocada (vermelho).
  missed,
}

class NoteComparison {
  final ExpectedNote expected;

  // Nota tocada pelo aluno (null = não tocada).
  final int? playedMidi;

  // Frequência medida pelo dispositivo (Hz).
  final double? playedFrequency;

  // Diferença de ataque: positivo = atrasado (ms).
  final int? onsetErrorMs;

  // Duração medida e esperada (ms).
  final int? playedDurationMs;
  final int expectedDurationMs;

  // Pontuações de 0 a 1.
  final double pitchScore;
  final double rhythmScore;

  final NoteFeedback feedback;

  const NoteComparison({
    required this.expected,
    required this.playedMidi,
    required this.playedFrequency,
    required this.onsetErrorMs,
    required this.playedDurationMs,
    required this.expectedDurationMs,
    required this.pitchScore,
    required this.rhythmScore,
    required this.feedback,
  });

  // Nota da execução: média entre altura e ritmo.
  double get score => (pitchScore + rhythmScore) / 2;

  bool get isHit => feedback == NoteFeedback.correct;
}

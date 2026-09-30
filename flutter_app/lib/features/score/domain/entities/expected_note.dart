import 'dart:math';

// Nota que o aluno deve tocar e que será avaliada (gabarito).
//
// Como o microfone capta uma nota por vez, a avaliação usa a melodia:
// a nota mais aguda de cada ataque da pauta superior, com as ligaduras
// de prolongamento somadas em uma única nota.
class ExpectedNote {
  // Posição na lista de notas esperadas.
  final int index;

  // Notas da partitura que representam esta nota (para colorir).
  final List<int> scoreNoteIds;

  // Nota MIDI esperada.
  final int midi;

  // Início e duração em semínimas.
  final double startBeat;
  final double durationBeats;

  // Frase musical a que pertence.
  final int phraseIndex;

  const ExpectedNote({
    required this.index,
    required this.scoreNoteIds,
    required this.midi,
    required this.startBeat,
    required this.durationBeats,
    required this.phraseIndex,
  });

  double get endBeat => startBeat + durationBeats;

  // Frequência fundamental esperada (Hz).
  double get frequency => 440.0 * pow(2, (midi - 69) / 12.0);

  // Nome da nota em português (Dó, Ré, Mi...).
  String get name => noteName(midi);

  static String noteName(int midi) {
    const names = [
      'Dó',
      'Dó#',
      'Ré',
      'Ré#',
      'Mi',
      'Fá',
      'Fá#',
      'Sol',
      'Sol#',
      'Lá',
      'Lá#',
      'Si',
    ];
    return '${names[midi % 12]} ${(midi ~/ 12) - 1}';
  }
}

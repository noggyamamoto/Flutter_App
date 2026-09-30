// Frase musical: trecho curto de compassos exibido e avaliado por vez
// (RFA04 / RFA07).
class Phrase {
  final int index;

  // Compassos incluídos (índices, inclusive).
  final int firstMeasure;
  final int lastMeasure;

  // Limites em semínimas.
  final double startBeat;
  final double endBeat;

  const Phrase({
    required this.index,
    required this.firstMeasure,
    required this.lastMeasure,
    required this.startBeat,
    required this.endBeat,
  });

  double get durationBeats => endBeat - startBeat;

  int get measureCount => lastMeasure - firstMeasure + 1;

  List<int> get measureIndexes => [
        for (var i = firstMeasure; i <= lastMeasure; i++) i,
      ];
}

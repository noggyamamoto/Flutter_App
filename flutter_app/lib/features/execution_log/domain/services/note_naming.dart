import 'dart:math';

// Nome de uma figura rítmica (semínima, colcheia...) e se a duração
// corresponde a ela exatamente.
class FigureName {
  final String name;
  final bool exact;

  const FigureName(this.name, {required this.exact});

  @override
  String toString() => exact ? name : '≈ $name';
}

// Nomes usados no log da execução: notas no padrão internacional (C4, B6)
// e figuras pela duração em semínimas (1 = semínima).
class NoteNaming {
  static const _pitchNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  static const _figures = <(double, String)>[
    (4, 'semibreve'),
    (3, 'mínima pontuada'),
    (2, 'mínima'),
    (1.5, 'semínima pontuada'),
    (1, 'semínima'),
    (0.75, 'colcheia pontuada'),
    (0.5, 'colcheia'),
    (0.375, 'semicolcheia pontuada'),
    (0.25, 'semicolcheia'),
    (0.1875, 'fusa pontuada'),
    (0.125, 'fusa'),
    (0.0625, 'semifusa'),
  ];

  // 60 -> C4, 95 -> B6.
  static String pitch(int midi) {
    if (midi < 0 || midi > 127) return '--';
    return '${_pitchNames[midi % 12]}${midi ~/ 12 - 1}';
  }

  // Figura mais próxima (em escala logarítmica: o dobro e a metade ficam
  // igualmente longe). `tolerance` em oitavas: 0.15 ≈ 10% de diferença.
  static FigureName figure(double quarters, {double tolerance = 0.15}) {
    if (quarters <= 0) return const FigureName('?', exact: false);
    var best = _figures.first;
    var bestDistance = double.infinity;
    for (final figure in _figures) {
      final distance = (log(quarters / figure.$1) / ln2).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = figure;
      }
    }
    return FigureName(best.$2, exact: bestDistance < tolerance);
  }
}

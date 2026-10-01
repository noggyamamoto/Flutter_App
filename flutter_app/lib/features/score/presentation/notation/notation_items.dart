import 'dart:ui';

// Primitivas de desenho geradas pelo motor de gravação (ScoreEngraver) e
// desenhadas pelo ScorePainter.
//
// Cada primitiva pode estar ligada a uma ou mais notas da partitura
// (`noteIds`). Assim o painter pinta a cabeça, o acidente, a haste e os
// pontos de uma nota com a cor do feedback sem refazer o layout.
sealed class NotationItem {
  // Notas representadas por este elemento (vazio = tinta padrão).
  final List<int> noteIds;

  // Barras de colcheia só recebem cor quando todas as notas do grupo têm a
  // mesma cor; os demais elementos usam a cor da primeira nota colorida.
  final bool colorOnlyIfUniform;

  const NotationItem({this.noteIds = const [], this.colorOnlyIfUniform = false});

  NotationItem translate(double dx, double dy);

  // Limites verticais (para calcular a distância entre pautas).
  double get minY;
  double get maxY;
}

// Glifo SMuFL: a origem (linha base) fica em `origin`.
class GlyphItem extends NotationItem {
  final int glyph;
  final Offset origin;
  final double fontSize;

  // Extensão vertical do glifo em pixels (acima e abaixo da origem).
  final double ascent;
  final double descent;

  // Escala vertical extra (usada na chave do piano).
  final double scaleY;

  const GlyphItem({
    required this.glyph,
    required this.origin,
    required this.fontSize,
    required this.ascent,
    required this.descent,
    this.scaleY = 1,
    super.noteIds,
  });

  @override
  GlyphItem translate(double dx, double dy) => GlyphItem(
        glyph: glyph,
        origin: origin.translate(dx, dy),
        fontSize: fontSize,
        ascent: ascent,
        descent: descent,
        scaleY: scaleY,
        noteIds: noteIds,
      );

  @override
  double get minY => origin.dy - ascent * scaleY;

  @override
  double get maxY => origin.dy + descent * scaleY;
}

// Linha reta (linhas suplementares, hastes, barras de compasso).
class LineItem extends NotationItem {
  final Offset a;
  final Offset b;
  final double width;

  // true = linha da pauta/barra (sempre na cor da tinta).
  final bool structural;

  const LineItem({
    required this.a,
    required this.b,
    required this.width,
    this.structural = false,
    super.noteIds,
  });

  @override
  LineItem translate(double dx, double dy) => LineItem(
        a: a.translate(dx, dy),
        b: b.translate(dx, dy),
        width: width,
        structural: structural,
        noteIds: noteIds,
      );

  @override
  double get minY => (a.dy < b.dy ? a.dy : b.dy) - width / 2;

  @override
  double get maxY => (a.dy > b.dy ? a.dy : b.dy) + width / 2;
}

// Polígono preenchido (barras de colcheia, barra final grossa).
class PolygonItem extends NotationItem {
  final List<Offset> points;

  const PolygonItem({
    required this.points,
    super.noteIds,
    super.colorOnlyIfUniform,
  });

  @override
  PolygonItem translate(double dx, double dy) => PolygonItem(
        points: [for (final p in points) p.translate(dx, dy)],
        noteIds: noteIds,
        colorOnlyIfUniform: colorOnlyIfUniform,
      );

  @override
  double get minY => points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);

  @override
  double get maxY => points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
}

// Ligadura de prolongamento (curva com espessura variável).
class TieItem extends NotationItem {
  final Offset start;
  final Offset end;
  final bool above;

  // Espaço da pauta (define altura e espessura da curva).
  final double space;

  const TieItem({
    required this.start,
    required this.end,
    required this.above,
    required this.space,
    super.noteIds,
  });

  double get height => (space * (0.45 + 0.04 * ((end.dx - start.dx) / space))).clamp(space * 0.5, space * 1.2);

  @override
  TieItem translate(double dx, double dy) => TieItem(
        start: start.translate(dx, dy),
        end: end.translate(dx, dy),
        above: above,
        space: space,
        noteIds: noteIds,
      );

  @override
  double get minY => above ? start.dy - height - space * 0.2 : start.dy;

  @override
  double get maxY => above ? start.dy : start.dy + height + space * 0.2;
}

// Texto comum (número do compasso, andamento).
class TextItem extends NotationItem {
  final String text;

  // Linha base à esquerda.
  final Offset origin;
  final double size;
  final bool italic;
  final bool bold;
  final bool muted;

  const TextItem({
    required this.text,
    required this.origin,
    required this.size,
    this.italic = false,
    this.bold = false,
    this.muted = false,
  });

  @override
  TextItem translate(double dx, double dy) => TextItem(
        text: text,
        origin: origin.translate(dx, dy),
        size: size,
        italic: italic,
        bold: bold,
        muted: muted,
      );

  @override
  double get minY => origin.dy - size;

  @override
  double get maxY => origin.dy + size * 0.25;
}

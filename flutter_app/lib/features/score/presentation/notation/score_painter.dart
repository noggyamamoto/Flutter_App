import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'notation_items.dart';
import 'score_engraver.dart';
import 'smufl.dart';

// Cores usadas pela partitura.
class ScorePalette {
  // Tinta da partitura (notas ainda não avaliadas, pautas, claves).
  final Color ink;

  // Textos secundários (número do compasso).
  final Color muted;

  // Cursor de execução e destaque da próxima nota.
  final Color accent;

  const ScorePalette({
    this.ink = const Color(0xFF15131F),
    this.muted = const Color(0xFF6E6A80),
    this.accent = const Color(0xFF7C4DFF),
  });
}

// Desenha as primitivas geradas pelo ScoreEngraver.
//
// O layout não muda durante a execução: somente as cores das notas
// (feedback) são atualizadas, por isso este painter fica em uma camada
// separada do cursor (ScoreCursorPainter), que é redesenhado a cada quadro.
class ScorePainter extends CustomPainter {
  final EngravedScore layout;
  final Map<int, Color> noteColors;
  final ScorePalette palette;

  // Fonte dos textos (null = padrão da plataforma).
  final String? textFontFamily;

  ScorePainter({
    required this.layout,
    required this.noteColors,
    this.palette = const ScorePalette(),
    this.textFontFamily,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final system in layout.systems) {
      for (final item in system.items) {
        _paintItem(canvas, item);
      }
    }
  }

  Color _colorOf(NotationItem item) {
    if (item.noteIds.isEmpty) return palette.ink;
    if (item.colorOnlyIfUniform) {
      final colors = item.noteIds.map((id) => noteColors[id]).toSet();
      return colors.length == 1 && colors.first != null ? colors.first! : palette.ink;
    }
    for (final id in item.noteIds) {
      final c = noteColors[id];
      if (c != null) return c;
    }
    return palette.ink;
  }

  void _paintItem(Canvas canvas, NotationItem item) {
    final color = _colorOf(item);
    switch (item) {
      case GlyphItem():
        GlyphCache.paint(canvas, item.glyph, item.origin, item.fontSize, color, scaleY: item.scaleY);
      case LineItem():
        canvas.drawLine(
          item.a,
          item.b,
          Paint()
            ..color = item.structural ? palette.ink : color
            ..strokeWidth = item.width
            ..strokeCap = StrokeCap.butt,
        );
      case PolygonItem():
        final path = Path()..addPolygon(item.points, true);
        canvas.drawPath(path, Paint()..color = color);
      case TieItem():
        canvas.drawPath(_tiePath(item), Paint()..color = color);
      case TextItem():
        final painter = TextPainter(
          text: TextSpan(
            text: item.text,
            style: TextStyle(
              fontFamily: textFontFamily,
              color: item.muted ? palette.muted : palette.ink,
              fontSize: item.size,
              fontStyle: item.italic ? FontStyle.italic : FontStyle.normal,
              fontWeight: item.bold ? FontWeight.bold : FontWeight.w500,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        painter.paint(canvas, item.origin.translate(0, -baseline));
    }
  }

  // Ligadura: duas curvas de Bézier (externa e interna) com espessura
  // maior no meio, como nas partituras impressas.
  Path _tiePath(TieItem tie) {
    final s = tie.space;
    final dir = tie.above ? -1.0 : 1.0;
    final a = tie.start;
    final b = tie.end;
    final len = b.dx - a.dx;
    final h = tie.height;
    final end = Smufl.tieEndpointThickness * s;
    final mid = Smufl.tieMidpointThickness * s;
    final inset = math.min(len * 0.25, s * 1.2);

    final c1 = Offset(a.dx + inset, a.dy + dir * h);
    final c2 = Offset(b.dx - inset, b.dy + dir * h);
    final c1i = c1.translate(0, -dir * mid);
    final c2i = c2.translate(0, -dir * mid);

    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy)
      ..lineTo(b.dx, b.dy - dir * end)
      ..cubicTo(c2i.dx, c2i.dy, c1i.dx, c1i.dy, a.dx, a.dy - dir * end)
      ..close();
  }

  @override
  bool shouldRepaint(covariant ScorePainter old) =>
      old.layout != layout || old.noteColors != noteColors || old.palette != palette;
}

// Cursor de execução (linha vertical que acompanha o tempo) e destaque da
// próxima nota esperada, redesenhados a cada quadro.
class ScoreCursorPainter extends CustomPainter {
  final EngravedScore layout;
  final double? cursorBeat;
  final Set<int> activeNoteIds;
  final ScorePalette palette;

  ScoreCursorPainter({
    required this.layout,
    required this.cursorBeat,
    required this.activeNoteIds,
    this.palette = const ScorePalette(),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = layout.space;

    // Halo atrás da próxima nota a ser tocada.
    for (final id in activeNoteIds) {
      final rect = layout.noteBounds[id];
      if (rect == null) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(s * 0.55), Radius.circular(s)),
        Paint()..color = palette.accent.withValues(alpha: 0.18),
      );
    }

    final beat = cursorBeat;
    if (beat == null) return;
    final located = layout.locate(beat);
    if (located == null) return;
    final (system, x) = located;
    final top = system.staffTops.first - s * 1.5;
    final bottom = system.staffTops.last + s * 5.5;

    // Faixa suave + linha central (playhead).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - s * 0.9, top, x + s * 1.9, bottom),
        Radius.circular(s * 0.7),
      ),
      Paint()..color = palette.accent.withValues(alpha: 0.10),
    );
    canvas.drawLine(
      Offset(x + s * 0.5, top),
      Offset(x + s * 0.5, bottom),
      Paint()
        ..color = palette.accent.withValues(alpha: 0.85)
        ..strokeWidth = math.max(2, s * 0.22)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant ScoreCursorPainter old) =>
      old.layout != layout ||
      old.cursorBeat != cursorBeat ||
      old.activeNoteIds != activeNoteIds ||
      old.palette != palette;
}

// Cache dos parágrafos de glifos SMuFL (layout de texto é caro e os mesmos
// símbolos se repetem muitas vezes).
class GlyphCache {
  GlyphCache._();

  static final Map<String, (TextPainter, double)> _cache = {};

  static void paint(
    Canvas canvas,
    int glyph,
    Offset origin,
    double fontSize,
    Color color, {
    double scaleY = 1,
  }) {
    final key = '$glyph|${fontSize.toStringAsFixed(2)}|${color.toARGB32()}';
    var entry = _cache[key];
    if (entry == null) {
      if (_cache.length > 2000) _cache.clear();
      final painter = TextPainter(
        text: TextSpan(
          text: Smufl.char(glyph),
          style: TextStyle(
            fontFamily: Smufl.fontFamily,
            fontSize: fontSize,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      entry = (painter, baseline);
      _cache[key] = entry;
    }
    final (painter, baseline) = entry;
    if (scaleY == 1) {
      painter.paint(canvas, Offset(origin.dx, origin.dy - baseline));
    } else {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(1, scaleY);
      painter.paint(canvas, Offset(0, -baseline));
      canvas.restore();
    }
  }
}

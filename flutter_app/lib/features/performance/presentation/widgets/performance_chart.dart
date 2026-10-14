import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../history/domain/services/evolution_stats.dart';
import 'feedback_colors.dart';

// Gráfico de evolução (RFA11 / RU14), no padrão dos apps que acompanham o
// progresso do aluno: eixo de 0 a 100% com grade discreta, faixas de
// desempenho (verde ≥ 80, amarelo 50–79, vermelho < 50, as mesmas cores do
// feedback das notas), linha da pontuação com área suave, média móvel das
// últimas 3 execuções, destaque da melhor e da última execução e seleção por
// toque/arraste com o valor e a data da execução.
class PerformanceChart extends StatelessWidget {
  // Pontuações (0 a 100) da execução mais antiga para a mais recente.
  final List<double> values;

  // Data de cada execução (mesma ordem de `values`).
  final List<DateTime>? dates;

  // Número da primeira execução exibida (1 = primeira da música).
  final int firstOrdinal;

  // Execução selecionada (índice em `values`).
  final int? selectedIndex;

  // Toque ou arraste sobre o gráfico: execução mais próxima.
  final ValueChanged<int>? onSelected;

  // Mostra a média móvel (a partir de 4 execuções).
  final bool showAverage;

  final double height;

  const PerformanceChart({
    super.key,
    required this.values,
    this.dates,
    this.firstOrdinal = 1,
    this.selectedIndex,
    this.onSelected,
    this.showAverage = true,
    this.height = 220,
  });

  static const averageWindow = 3;

  bool get _averageVisible => showAverage && values.length >= 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Sem dados suficientes.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    final best = values.reduce(math.max);
    final semantics = 'Gráfico de evolução: ${values.length} execuções, '
        'primeira ${values.first.round()}%, última ${values.last.round()}%, '
        'melhor ${best.round()}%.';

    return Semantics(
      label: semantics,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, height);
            final geometry = _ChartGeometry(size, values.length);

            void select(Offset position) {
              final index = geometry.nearestIndex(position.dx);
              if (index != null) onSelected?.call(index);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onSelected == null ? null : (d) => select(d.localPosition),
              onHorizontalDragStart: onSelected == null ? null : (d) => select(d.localPosition),
              onHorizontalDragUpdate: onSelected == null ? null : (d) => select(d.localPosition),
              child: CustomPaint(
                size: size,
                painter: _PerformanceChartPainter(
                  values: values,
                  average: _averageVisible
                      ? EvolutionStats.movingAverage(values, window: averageWindow)
                      : null,
                  dates: dates,
                  firstOrdinal: firstOrdinal,
                  selectedIndex: selectedIndex,
                  colors: colors,
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}

// Legenda do gráfico: faixas de desempenho e as duas linhas.
class PerformanceChartLegend extends StatelessWidget {
  final bool showAverage;

  const PerformanceChartLegend({super.key, this.showAverage = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextStyle(color: colors.textSecondary, fontSize: 12);

    Widget line(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Text(label, style: style),
          ],
        );

    Widget band(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: style),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        line(colors.primary, 'Pontuação'),
        if (showAverage) line(colors.textMuted, 'Média das últimas 3'),
        band(FeedbackColors.correct, 'Ótimo (80+)'),
        band(FeedbackColors.approximate, 'Bom (50–79)'),
        band(FeedbackColors.incorrect, 'Praticar (< 50)'),
      ],
    );
  }
}

// Posição de cada execução na área do gráfico.
class _ChartGeometry {
  static const left = 40.0;
  static const right = 14.0;
  static const top = 28.0;
  static const bottom = 26.0;

  final Size size;
  final int count;

  _ChartGeometry(this.size, this.count);

  Rect get plot => Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  double x(int index) {
    if (count <= 1) return plot.center.dx;
    return plot.left + plot.width * index / (count - 1);
  }

  double y(double value) => plot.bottom - plot.height * value.clamp(0, 100) / 100;

  int? nearestIndex(double dx) {
    if (count == 0) return null;
    if (count == 1) return 0;
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * (count - 1)).round();
  }
}

class _PerformanceChartPainter extends CustomPainter {
  final List<double> values;
  final List<double>? average;
  final List<DateTime>? dates;
  final int firstOrdinal;
  final int? selectedIndex;
  final AppColors colors;
  final String? fontFamily;

  _PerformanceChartPainter({
    required this.values,
    required this.average,
    required this.dates,
    required this.firstOrdinal,
    required this.selectedIndex,
    required this.colors,
    required this.fontFamily,
  });

  TextPainter _text(String text, {double size = 11, Color? color, FontWeight? weight}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          color: color ?? colors.textMuted,
          fontWeight: weight,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _ChartGeometry(size, values.length);
    final plot = g.plot;

    // Faixas de desempenho (as cores do feedback, bem suaves).
    final bands = [
      (80.0, 100.0, FeedbackColors.correct),
      (50.0, 80.0, FeedbackColors.approximate),
      (0.0, 50.0, FeedbackColors.incorrect),
    ];
    for (final (from, to, color) in bands) {
      canvas.drawRect(
        Rect.fromLTRB(plot.left, g.y(to), plot.right, g.y(from)),
        Paint()..color = color.withValues(alpha: colors.isDark ? 0.07 : 0.08),
      );
    }

    // Grade (linhas finas e contínuas) e eixo de 0 a 100%.
    final grid = Paint()
      ..color = colors.subtle
      ..strokeWidth = 1;
    for (final tick in const [0, 25, 50, 75, 100]) {
      final y = g.y(tick.toDouble());
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = _text('$tick%');
      label.paint(canvas, Offset(plot.left - label.width - 8, y - label.height / 2));
    }

    // Eixo X: número da execução (1ª, 2ª...), até ~6 marcas.
    final count = values.length;
    final maxTicks = math.max(2, (plot.width / 56).floor());
    final step = math.max(1, ((count - 1) / (maxTicks - 1)).ceil());
    final ticks = <int>{for (var i = 0; i < count; i += step) i, count - 1};
    double lastRight = -double.infinity;
    for (final i in ticks.toList()..sort()) {
      final label = _text('${firstOrdinal + i}ª');
      final x = g.x(i) - label.width / 2;
      // A última marca sempre aparece; as outras só se não encostarem.
      if (x < lastRight + 6 && i != count - 1) continue;
      label.paint(canvas, Offset(x, plot.bottom + 8));
      lastRight = x + label.width;
    }

    final points = [for (var i = 0; i < count; i++) Offset(g.x(i), g.y(values[i]))];

    // Área sob a linha (véu da cor da série).
    if (count > 1) {
      final area = Path()..moveTo(points.first.dx, plot.bottom);
      for (final p in points) {
        area.lineTo(p.dx, p.dy);
      }
      area
        ..lineTo(points.last.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.16),
              colors.primary.withValues(alpha: 0.0),
            ],
          ).createShader(plot),
      );
    }

    // Média móvel (tendência), discreta.
    final avg = average;
    if (avg != null && avg.length == count) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = Offset(g.x(i), g.y(avg[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.textMuted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Linha da pontuação.
    if (count > 1) {
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Guia vertical da execução selecionada.
    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < count) {
      final x = points[selected].dx;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = colors.outline
          ..strokeWidth = 1,
      );
    }

    // Pontos coloridos pela faixa, com anel na cor da superfície.
    final dense = count > 30;
    final radius = dense ? 3.0 : 4.5;
    var bestIndex = 0;
    for (var i = 1; i < count; i++) {
      if (values[i] >= values[bestIndex]) bestIndex = i;
    }
    for (var i = 0; i < count; i++) {
      final highlight = i == selected || i == count - 1 || i == bestIndex;
      if (dense && !highlight) continue;
      final r = i == selected ? radius + 2 : radius;
      canvas.drawCircle(points[i], r + 2, Paint()..color = colors.surface);
      canvas.drawCircle(points[i], r, Paint()..color = FeedbackColors.forScore(values[i]));
    }

    // Anel dourado na melhor execução.
    canvas.drawCircle(
      points[bestIndex],
      radius + 4.5,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Rótulos seletivos: melhor e última execução (ou a selecionada).
    void label(int i, String text, {bool strong = false}) {
      final tp = _text(text, size: 11.5, color: strong ? colors.textPrimary : colors.textSecondary, weight: FontWeight.bold);
      var dx = points[i].dx - tp.width / 2;
      dx = dx.clamp(plot.left, size.width - tp.width - 2);
      var dy = points[i].dy - tp.height - radius - 8;
      if (dy < 2) dy = points[i].dy + radius + 6;
      tp.paint(canvas, Offset(dx, dy));
    }

    if (selected != null && selected >= 0 && selected < count) {
      _tooltip(canvas, size, plot, points[selected], selected);
    } else {
      label(count - 1, '${values.last.round()}%', strong: true);
      if (bestIndex != count - 1) label(bestIndex, 'Melhor ${values[bestIndex].round()}%');
    }
  }

  // Balão da execução selecionada: valor e data.
  void _tooltip(Canvas canvas, Size size, Rect plot, Offset point, int index) {
    final date = dates != null && index < dates!.length ? dates![index] : null;
    final title = _text('${values[index].round()}%', size: 13, color: colors.textPrimary, weight: FontWeight.bold);
    final subtitle = _text(
      '${firstOrdinal + index}ª execução'
      '${date != null ? ' · ${_two(date.day)}/${_two(date.month)}' : ''}',
      size: 11,
      color: colors.textSecondary,
    );
    const pad = 8.0;
    final width = math.max(title.width, subtitle.width) + pad * 2;
    final height = title.height + subtitle.height + pad * 2 - 2;
    var left = point.dx - width / 2;
    // Dentro da área do gráfico (sem cobrir os rótulos do eixo).
    left = left.clamp(plot.left - 4, math.max(plot.left - 4, size.width - width - 2));
    var top = point.dy - height - 14;
    if (top < 0) top = point.dy + 14;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width, height), const Radius.circular(8));
    canvas.drawRRect(
      rect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.12),
    );
    canvas.drawRRect(rect, Paint()..color = colors.surfaceHigh);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke,
    );
    title.paint(canvas, Offset(left + pad, top + pad - 1));
    subtitle.paint(canvas, Offset(left + pad, top + pad - 1 + title.height));
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  bool shouldRepaint(covariant _PerformanceChartPainter old) {
    return old.values != values ||
        old.average != average ||
        old.selectedIndex != selectedIndex ||
        old.firstOrdinal != firstOrdinal ||
        old.colors != colors ||
        old.dates != dates;
  }
}

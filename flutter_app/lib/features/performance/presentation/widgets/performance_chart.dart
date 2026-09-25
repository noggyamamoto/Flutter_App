import 'package:flutter/material.dart';

class PerformanceChart extends StatelessWidget {
  final List<double> values;

  const PerformanceChart({
    super.key,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Sem dados suficientes.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(
        painter: _PerformanceChartPainter(values),
      ),
    );
  }
}

class _PerformanceChartPainter extends CustomPainter {
  final List<double> values;

  _PerformanceChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final path = Path();

    final double step = values.length == 1
        ? 0
        : size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final double x = i * step;

      final double normalized =
          values[i].clamp(0, 100) / 100;

      final double y =
          size.height - normalized * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(
      path,
      linePaint,
    );

    final pointPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final double x = i * step;

      final double normalized =
          values[i].clamp(0, 100) / 100;

      final double y =
          size.height - normalized * size.height;

      canvas.drawCircle(
        Offset(x, y),
        4,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _PerformanceChartPainter oldDelegate,
  ) {
    return oldDelegate.values != values;
  }
}
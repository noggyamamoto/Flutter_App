import 'package:flutter/material.dart';

class MusicHistoryWidget
    extends StatelessWidget {
  const MusicHistoryWidget({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 230,
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter:
            _MusicHistoryPainter(),
      ),
    );
  }
}

class _MusicHistoryPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2;

    const spacing = 12.0;

    for (int i = 0; i < 5; i++) {
      final y =
          45 + i * spacing;

      canvas.drawLine(
        Offset(20, y),
        Offset(
          size.width - 20,
          y,
        ),
        linePaint,
      );
    }

    final notePaint = Paint()
      ..color = Colors.green
      ..style =
          PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      final x =
          70 + i * 45.0;

      final y =
          90 -
          (i % 3) * 12.0;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            x,
            y,
          ),
          width: 16,
          height: 11,
        ),
        notePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant
        _MusicHistoryPainter
            oldDelegate,
  ) {
    return false;
  }
}
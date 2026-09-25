import 'package:flutter/material.dart';

import '../../domain/entities/midi_score.dart';

class ScoreDisplay extends StatelessWidget {
  final MidiScore score;

  const ScoreDisplay({
    super.key,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    if (score.notes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma nota encontrada.',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 250,
      child: CustomPaint(
        painter: _ScorePainter(score),
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  final MidiScore score;

  _ScorePainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final staffPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final notePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    const double staffSpacing = 18;
    const double staffTop = 70;

    // Desenha as 5 linhas da pauta.
    for (int i = 0; i < 5; i++) {
      final double y = staffTop + i * staffSpacing;

      canvas.drawLine(
        Offset(20, y),
        Offset(size.width - 20, y),
        staffPaint,
      );
    }

    // Desenha uma clave de sol simplificada.
    final clefText = TextPainter(
      text: const TextSpan(
        text: '𝄞',
        style: TextStyle(
          color: Colors.black,
          fontSize: 65,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    clefText.layout();

    clefText.paint(
      canvas,
      const Offset(25, 25),
    );

    if (score.notes.isEmpty) {
      return;
    }

    // Espaçamento horizontal entre as notas.
    final double availableWidth = size.width - 130;

    final double noteSpacing = score.notes.length == 1
        ? 0
        : availableWidth / (score.notes.length - 1);

    for (int i = 0; i < score.notes.length; i++) {
      final note = score.notes[i];

      final double x = 110 + i * noteSpacing;

      final double y = _getNoteY(note.midi);

      // Cabeça da nota.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 14,
          height: 10,
        ),
        notePaint,
      );

      // Haste da nota.
      canvas.drawLine(
        Offset(x + 6, y),
        Offset(x + 6, y - 35),
        notePaint,
      );
    }
  }

  double _getNoteY(int midi) {
    // MIDI 60 = Dó central.
    const int middleC = 60;

    final int difference = midi - middleC;

    // Aproximação visual:
    // cada semitom corresponde a um pequeno deslocamento vertical.
    const double semitoneSpacing = 3.0;

    return 106 - difference * semitoneSpacing;
  }

  @override
  bool shouldRepaint(
    covariant _ScorePainter oldDelegate,
  ) {
    return oldDelegate.score != score;
  }
}
import 'package:flutter/material.dart';

import '../../../score/domain/entities/note_comparison.dart';

// Cores do feedback em tempo real (RFA06): verde = acerto,
// laranja = aproximado, vermelho = erro.
class FeedbackColors {
  static const correct = Colors.green;
  static const approximate = Colors.orange;
  static const incorrect = Colors.red;

  static Color? of(NoteFeedback feedback) => switch (feedback) {
        NoteFeedback.correct => correct,
        NoteFeedback.approximate => approximate,
        NoteFeedback.incorrect || NoteFeedback.missed => incorrect,
        NoteFeedback.pending => null,
      };

  // Converte o mapa de feedback (id da nota -> resultado) em cores.
  static Map<int, Color> map(Map<int, NoteFeedback> feedback) {
    final colors = <int, Color>{};
    feedback.forEach((id, value) {
      final color = of(value);
      if (color != null) colors[id] = color;
    });
    return colors;
  }

  // Cores do metrônomo visual, iguais às do LED RGB do dispositivo (RFE03).
  static Color meter(int beatsPerBar, {bool countIn = false}) {
    if (countIn) return const Color(0xFFFFB400);
    return switch (beatsPerBar) {
      2 => const Color(0xFF3D7BFF),
      3 => const Color(0xFF2EDB6A),
      _ => const Color(0xFFB44DFF),
    };
  }
}

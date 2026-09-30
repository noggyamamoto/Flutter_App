import 'package:flutter/material.dart';

import 'feedback_colors.dart';

// Metrônomo visual na tela (RU06): um ponto por tempo, com a cor da
// fórmula de compasso (azul = binário, verde = ternário, roxo = quaternário).
class VisualMetronome extends StatelessWidget {
  final int beatInBar;
  final int beatsPerBar;

  const VisualMetronome({
    super.key,
    required this.beatInBar,
    required this.beatsPerBar,
  });

  @override
  Widget build(BuildContext context) {
    final color = FeedbackColors.meter(beatsPerBar);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= beatsPerBar; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == beatInBar ? 14 : 10,
            height: i == beatInBar ? 14 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == beatInBar
                  ? (i == 1 ? color : color.withValues(alpha: 0.6))
                  : Colors.white24,
            ),
          ),
      ],
    );
  }
}

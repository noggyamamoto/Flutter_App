import 'package:flutter/material.dart';

import 'feedback_colors.dart';

// Contagem de entrada: dois compassos vazios no andamento da música,
// com aviso visual (RFA05 / RU07). O aviso sonoro é tocado pelo
// buzzer do dispositivo (ou pelo app no modo demonstração).
class CountdownWidget extends StatelessWidget {
  // Tempo atual (1..beatsPerBar) e compasso atual (1..totalBars).
  final int beat;
  final int bar;
  final int beatsPerBar;
  final int totalBars;

  const CountdownWidget({
    super.key,
    required this.beat,
    required this.bar,
    required this.beatsPerBar,
    this.totalBars = 2,
  });

  @override
  Widget build(BuildContext context) {
    final color = FeedbackColors.meter(beatsPerBar, countIn: true);

    return Container(
      color: const Color(0xFF0F0E17).withValues(alpha: 0.82),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Prepare-se!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
            ),
          ),

          const SizedBox(height: 8),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '$beat',
              key: ValueKey('$bar-$beat'),
              style: TextStyle(
                color: beat == 1 ? color : Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Um ponto por tempo do compasso.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= beatsPerBar; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: i == beat ? 22 : 14,
                  height: i == beat ? 22 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= beat ? color : Colors.white24,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Compasso $bar de $totalBars',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

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

          // O número aparece inteiro no quadro da batida e só "assenta"
          // (de 115% para 100%): antes ele crescia do zero em 120 ms e a
          // contagem parecia atrasada em relação ao clique.
          TweenAnimationBuilder<double>(
            key: ValueKey('$bar-$beat'),
            tween: Tween(begin: 1.15, end: 1.0),
            duration: const Duration(milliseconds: 140),
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Text(
              '$beat',
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
                Container(
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

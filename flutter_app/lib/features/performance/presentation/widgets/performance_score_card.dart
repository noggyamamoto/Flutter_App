import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'feedback_colors.dart';
import 'performance_hud.dart';

// Resumo da performance (RU13 / RFA10), no padrão dos apps de prática:
// estrelas e mensagem de incentivo, precisão em anel, notas tocadas,
// conceito (A+ a F) e maior sequência de acertos.
class PerformanceScoreCard extends StatelessWidget {
  final double precision;
  final int notesPlayed;
  final int? bestStreak;

  const PerformanceScoreCard({
    super.key,
    required this.precision,
    required this.notesPlayed,
    this.bestStreak,
  });

  // Conceito avaliativo a partir da precisão.
  static String grade(double precision) {
    if (precision >= 95) return 'A+';
    if (precision >= 90) return 'A';
    if (precision >= 80) return 'B+';
    if (precision >= 70) return 'B';
    if (precision >= 60) return 'C';
    if (precision >= 50) return 'D';
    return 'F';
  }

  static int stars(double precision) {
    if (precision >= 90) return 3;
    if (precision >= 70) return 2;
    if (precision >= 50) return 1;
    return 0;
  }

  static String headline(double precision) {
    if (precision >= 90) return 'Excelente!';
    if (precision >= 70) return 'Muito bem!';
    if (precision >= 50) return 'Bom trabalho!';
    return 'Continue praticando!';
  }

  @override
  Widget build(BuildContext context) {
    final color = FeedbackColors.forScore(precision);
    final starCount = stars(precision);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == 1 ? 10 : 0),
                  child: Icon(
                    i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: i == 1 ? 52 : 40,
                    color: i < starCount ? const Color(0xFFFFC233) : Colors.white24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            headline(precision),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              HudStat(
                label: 'Precisão',
                value: AccuracyRing(precision: precision, size: 64),
              ),
              HudStat(
                label: 'Notas tocadas',
                value: Text(
                  '$notesPlayed',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              HudStat(
                label: 'Conceito',
                value: Text(
                  grade(precision),
                  style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              if (bestStreak != null)
                HudStat(
                  label: 'Maior sequência',
                  value: Text(
                    '$bestStreak',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

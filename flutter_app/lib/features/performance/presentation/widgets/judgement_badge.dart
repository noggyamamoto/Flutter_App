import 'package:flutter/material.dart';

import '../../../score/domain/entities/note_comparison.dart';
import '../../domain/entities/performance_state.dart';
import 'feedback_colors.dart';
import 'score_display.dart';

// Selo animado exibido logo acima da nota avaliada ("Perfeito!",
// "Atrasado", "Nota errada"...), como nos apps de prática musical.
class JudgementBadge extends StatelessWidget {
  final NoteJudgement judgement;
  final EngravedScore layout;

  const JudgementBadge({super.key, required this.judgement, required this.layout});

  @override
  Widget build(BuildContext context) {
    final color = FeedbackColors.of(judgement.feedback) ?? FeedbackColors.incorrect;
    final bounds = judgement.noteId != null ? layout.noteBounds[judgement.noteId!] : null;

    // Nota extra (sem correspondência): selo no canto superior.
    final anchor = bounds != null
        ? Offset(bounds.center.dx, bounds.top - layout.space * 2.2)
        : Offset(layout.width - 70, 18);

    final icon = switch (judgement.feedback) {
      NoteFeedback.correct => Icons.check_rounded,
      NoteFeedback.approximate => Icons.timelapse_rounded,
      _ => Icons.close_rounded,
    };

    return Positioned(
      left: (anchor.dx - 60).clamp(0.0, (layout.width - 120).clamp(0.0, double.infinity)),
      top: anchor.dy.clamp(0.0, (layout.height - 30).clamp(0.0, double.infinity)),
      width: 120,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(judgement.serial),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (context, t, child) {
            // Entra subindo e crescendo; some no final.
            final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
            final scale = t < 0.15 ? 0.7 + t * 2 : 1.0;
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -12 * t),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    judgement.label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

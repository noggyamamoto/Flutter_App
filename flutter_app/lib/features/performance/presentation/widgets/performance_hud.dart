import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'feedback_colors.dart';

// ==========================================================================
// Componentes do painel de execução (HUD), no padrão dos apps de prática
// musical (Simply Piano, Yousician): progresso por trechos no topo,
// precisão em anel, sequência de acertos e metrônomo.
// ==========================================================================

// Barra de progresso segmentada: um segmento por trecho (frase), colorido
// pelo resultado do trecho; o trecho atual mostra o avanço do cursor.
class PhraseProgressBar extends StatelessWidget {
  final int phraseCount;
  final int currentPhrase;

  // Avanço (0 a 1) dentro do trecho atual.
  final double currentProgress;

  // Pontuação de cada trecho avaliado.
  final Map<int, double> phraseScores;

  // Toque em um segmento (navegação antes de iniciar).
  final ValueChanged<int>? onTap;

  const PhraseProgressBar({
    super.key,
    required this.phraseCount,
    required this.currentPhrase,
    this.currentProgress = 0,
    this.phraseScores = const {},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < phraseCount; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap == null ? null : () => onTap!(i),
              child: Padding(
                padding: EdgeInsets.only(right: i == phraseCount - 1 ? 0 : 4, top: 6, bottom: 6),
                child: _segment(i),
              ),
            ),
          ),
      ],
    );
  }

  Widget _segment(int i) {
    final score = phraseScores[i];
    final isCurrent = i == currentPhrase;
    final color = score != null ? FeedbackColors.forScore(score) : AppColors.primary;
    final fill = score != null ? 1.0 : (isCurrent ? currentProgress.clamp(0.0, 1.0) : 0.0);

    return Semantics(
      label: 'Trecho ${i + 1}${score != null ? ', ${score.round()}%' : ''}',
      child: Container(
        height: isCurrent ? 8 : 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: isCurrent && score == null
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.9), width: 1)
              : null,
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fill,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// Precisão parcial em anel.
class AccuracyRing extends StatelessWidget {
  final double precision;
  final double size;
  final bool active;

  const AccuracyRing({
    super.key,
    required this.precision,
    this.size = 52,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? FeedbackColors.forScore(precision) : AppColors.textMuted;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: precision.clamp(0, 100) / 100),
        duration: const Duration(milliseconds: 350),
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(value: value, color: color),
          child: Center(
            child: Text(
              active ? '${precision.round()}%' : '--',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.27,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.color != color;
}

// Indicador de estatística do HUD (valor + legenda).
class HudStat extends StatelessWidget {
  final Widget value;
  final String label;

  const HudStat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        value,
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.3),
        ),
      ],
    );
  }
}

// Sequência de acertos ("combo"), com destaque a partir de 5 notas.
class StreakCounter extends StatelessWidget {
  final int streak;

  const StreakCounter({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final hot = streak >= 5;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Row(
        key: ValueKey(streak),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 22,
            color: hot ? const Color(0xFFFF8A3D) : AppColors.textMuted,
          ),
          const SizedBox(width: 2),
          Text(
            '$streak',
            style: TextStyle(
              color: hot ? Colors.white : AppColors.textSecondary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Pílula do andamento com o metrônomo visual integrado (RU06).
class TempoPill extends StatelessWidget {
  final int bpm;
  final int beatInBar;
  final int beatsPerBar;
  final bool showBeats;

  // Andamento reduzido em relação ao início (RU12): seta para baixo.
  final bool slowedDown;

  const TempoPill({
    super.key,
    required this.bpm,
    required this.beatInBar,
    required this.beatsPerBar,
    this.showBeats = true,
    this.slowedDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = FeedbackColors.meter(beatsPerBar);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (slowedDown)
              const Icon(Icons.south_rounded, color: Colors.amber, size: 16),
            Text(
              '$bpm',
              style: TextStyle(
                color: slowedDown ? Colors.amber : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (showBeats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= beatsPerBar.clamp(1, 12); i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: i == beatInBar ? 9 : 6,
                  height: i == beatInBar ? 9 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == beatInBar
                        ? (i == 1 ? color : color.withValues(alpha: 0.7))
                        : Colors.white24,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../performance/presentation/widgets/feedback_colors.dart';
import '../../../performance/presentation/widgets/performance_score_card.dart';
import '../../domain/entities/performance_history.dart';
import '../../domain/services/evolution_stats.dart';

// Lista das execuções de uma música (mais recentes primeiro). Cada cartão
// mostra a pontuação e o conceito, quando foi tocada, se foi concluída, o
// andamento, altura e ritmo e a diferença para a execução anterior. Tocar
// em um cartão reabre a execução com a mesma tela do fim da execução.
class PerformanceHistoryList
    extends StatelessWidget {

  // Lista de execuções que será exibida (mais recentes primeiro).
  final List<PerformanceHistory> history;

  // Execução aberta na tela (destacada).
  final String? currentExecutionId;

  // Toque em uma execução.
  final ValueChanged<PerformanceHistory>? onTap;

  // Data de referência para "Hoje"/"Ontem" (testes).
  final DateTime? now;

  const PerformanceHistoryList({
    super.key,
    required this.history,
    this.currentExecutionId,
    this.onTap,
    this.now,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors = context.colors;

    // Caso o usuário ainda não tenha
    // nenhuma execução dessa música.
    if (history.isEmpty) {

      return Padding(
        padding: const EdgeInsets.all(24),

        child: Center(
          child: Text(
            'Nenhuma execução anterior encontrada.',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final stats = EvolutionStats.from(history);

    // Lista das execuções.
    return ListView.builder(

      // Permite que a lista fique dentro
      // do SingleChildScrollView da página.
      shrinkWrap: true,

      // Evita conflito entre dois scrolls.
      physics:
          const NeverScrollableScrollPhysics(),

      // Quantidade de execuções.
      itemCount: history.length,

      itemBuilder: (
        context,
        index,
      ) {

        // Execução atual da lista.
        final performance =
            history[index];

        return _ExecutionCard(
          execution: performance,
          ordinal: stats.ordinalOf(performance.executionId) ?? history.length - index,
          previous: stats.previousOf(performance),
          isBest: stats.best?.executionId == performance.executionId,
          isCurrent: performance.executionId == currentExecutionId,
          now: now ?? DateTime.now(),
          onTap: onTap == null ? null : () => onTap!(performance),
        );
      },
    );
  }
}

class _ExecutionCard extends StatelessWidget {
  final PerformanceHistory execution;
  final int ordinal;
  final PerformanceHistory? previous;
  final bool isBest;
  final bool isCurrent;
  final DateTime now;
  final VoidCallback? onTap;

  const _ExecutionCard({
    required this.execution,
    required this.ordinal,
    required this.previous,
    required this.isBest,
    required this.isCurrent,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = execution.score;
    final scoreColor = FeedbackColors.forScore(score);
    final delta = previous == null ? null : score - previous!.score;
    final finalBpm = execution.finalBpm;
    final slowed = finalBpm != null && finalBpm < execution.bpm;

    return Padding(
      // Espaçamento entre os cards.
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent ? colors.primary : colors.border.withValues(alpha: colors.isDark ? 0.5 : 1),
                width: isCurrent ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Pontuação e conceito.
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${score.round()}%',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        PerformanceScoreCard.grade(score),
                        style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Informações da execução.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$ordinalª execução',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 6),
                            _Tag(
                              icon: Icons.emoji_events_rounded,
                              label: 'Melhor',
                              color: AppColors.gold,
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            _Tag(label: 'Aberta', color: colors.primary),
                          ],
                        ],
                      ),

                      const SizedBox(height: 3),

                      // Data e horário.
                      Text(
                        formatExecutionDate(execution.date, now: now),
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _Detail(
                            icon: execution.completed ? Icons.flag_rounded : Icons.pause_circle_outline,
                            text: execution.completed ? 'Concluída' : 'Interrompida',
                          ),
                          _Detail(
                            icon: Icons.speed_rounded,
                            text: slowed ? '${execution.bpm}→$finalBpm BPM' : '${execution.bpm} BPM',
                          ),
                          if (execution.pitchScore != null)
                            _Detail(
                              icon: Icons.music_note_rounded,
                              text: 'Altura ${execution.pitchScore!.round()}%',
                            ),
                          if (execution.rhythmScore != null)
                            _Detail(
                              icon: Icons.av_timer_rounded,
                              text: 'Ritmo ${execution.rhythmScore!.round()}%',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Diferença para a execução anterior.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (delta != null) DeltaLabel(delta: delta),
                    if (onTap != null) ...[
                      const SizedBox(height: 4),
                      Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Variação em pontos com seta (verde para cima, vermelha para baixo).
class DeltaLabel extends StatelessWidget {
  final double delta;
  final String suffix;

  const DeltaLabel({super.key, required this.delta, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rounded = delta.round();
    final (icon, color) = rounded > 0
        ? (Icons.arrow_upward_rounded, FeedbackColors.correct)
        : rounded < 0
            ? (Icons.arrow_downward_rounded, FeedbackColors.incorrect)
            : (Icons.remove_rounded, colors.textMuted);
    return Semantics(
      label: rounded == 0 ? 'Sem variação' : '${rounded > 0 ? 'Subiu' : 'Caiu'} ${rounded.abs()} pontos',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            '${rounded.abs()}$suffix',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  const _Tag({this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(color: colors.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

// "Hoje, 14:32", "Ontem, 09:10" ou "12/10/2026, 14:32".
String formatExecutionDate(DateTime date, {DateTime? now}) {
  String two(int v) => v.toString().padLeft(2, '0');
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(date.year, date.month, date.day);
  final time = '${two(date.hour)}:${two(date.minute)}';
  // Arredondado: dias com troca de horário de verão têm 23 ou 25 h.
  final days = (today.difference(day).inHours / 24).round();
  if (days == 0) return 'Hoje, $time';
  if (days == 1) return 'Ontem, $time';
  return '${two(date.day)}/${two(date.month)}/${date.year}, $time';
}

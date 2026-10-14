import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../performance/presentation/widgets/performance_chart.dart';
import '../../../performance/presentation/widgets/performance_score_card.dart';
import '../../domain/entities/performance_history.dart';
import '../../domain/services/evolution_stats.dart';
import 'performance_history_list.dart';

// Aba Evolução (RFA11 / RU14): resumo do progresso na música, gráfico da
// pontuação por execução e a lista das execuções, que podem ser reabertas.
class EvolutionPanel extends StatefulWidget {
  // Execuções da música (mais recentes primeiro).
  final List<PerformanceHistory> history;

  // Execução aberta na tela de resultado (destacada no gráfico e na lista).
  final String? currentExecutionId;

  // Abrir uma execução.
  final ValueChanged<PerformanceHistory>? onOpen;

  // Data de referência para "Hoje"/"Ontem" (testes).
  final DateTime? now;

  const EvolutionPanel({
    super.key,
    required this.history,
    this.currentExecutionId,
    this.onOpen,
    this.now,
  });

  // O gráfico aparece a partir da 10ª execução da mesma música (RFA11).
  static const chartMinimum = 10;

  @override
  State<EvolutionPanel> createState() => _EvolutionPanelState();
}

enum _Series { overall, pitch, rhythm }

class _EvolutionPanelState extends State<EvolutionPanel> {
  _Series _series = _Series.overall;

  // Quantidade de execuções no gráfico (null = todas).
  int? _period = 10;

  // Execução selecionada no gráfico (id).
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentExecutionId;
  }

  @override
  void didUpdateWidget(covariant EvolutionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentExecutionId != widget.currentExecutionId) {
      _selectedId = widget.currentExecutionId;
    }
  }

  double? _valueOf(PerformanceHistory h) => switch (_series) {
        _Series.overall => h.score,
        _Series.pitch => h.pitchScore,
        _Series.rhythm => h.rhythmScore,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stats = EvolutionStats.from(widget.history);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sua evolução nesta música',
          style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          stats.count == 0
              ? 'Nenhuma execução salva ainda.'
              : '${stats.count} ${stats.count == 1 ? 'execução' : 'execuções'} desde '
                  '${_date(stats.chronological.first.date)}',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 14),

        if (stats.count > 0) ...[
          _Summary(stats: stats),
          const SizedBox(height: 16),
          stats.count >= EvolutionPanel.chartMinimum
              ? _buildChartCard(stats)
              : _ChartLocked(count: stats.count),
          const SizedBox(height: 22),
          Text(
            'Execuções',
            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Toque em uma execução para ver o resumo e as notas tocadas.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],

        PerformanceHistoryList(
          history: widget.history,
          currentExecutionId: widget.currentExecutionId,
          onTap: widget.onOpen,
          now: widget.now,
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // GRÁFICO
  // -------------------------------------------------------

  Widget _buildChartCard(EvolutionStats stats) {
    final colors = context.colors;

    // Execuções com valor na série escolhida (execuções antigas não têm
    // altura e ritmo), limitadas ao período.
    final withValue = stats.chronological.where((h) => _valueOf(h) != null).toList();
    final period = _period;
    final shown = period != null && withValue.length > period
        ? withValue.sublist(withValue.length - period)
        : withValue;
    final firstOrdinal = shown.isEmpty ? 1 : stats.ordinalOf(shown.first.executionId) ?? 1;
    final selectedIndex = shown.indexWhere((h) => h.executionId == _selectedId);
    final selected = selectedIndex >= 0 ? shown[selectedIndex] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (_series) {
              _Series.overall => 'Pontuação geral por execução',
              _Series.pitch => 'Altura (notas certas) por execução',
              _Series.rhythm => 'Ritmo (tempo e duração) por execução',
            },
            style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'Da mais antiga (à esquerda) para a mais recente. Toque no gráfico para ver cada execução.',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Filtros: série e período.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final series in _Series.values)
                _FilterChip(
                  label: switch (series) {
                    _Series.overall => 'Geral',
                    _Series.pitch => 'Altura',
                    _Series.rhythm => 'Ritmo',
                  },
                  selected: _series == series,
                  onTap: () => setState(() => _series = series),
                ),
              if (withValue.length > 10) ...[
                const SizedBox(width: 8),
                for (final option in <int?>[10, 30, null])
                  if (option == null || withValue.length > option || option == 10)
                    _FilterChip(
                      label: option == null ? 'Todas' : 'Últimas $option',
                      selected: _period == option,
                      onTap: () => setState(() => _period = option),
                    ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          if (shown.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Ainda não há execuções suficientes com essa informação.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else ...[
            PerformanceChart(
              values: [for (final h in shown) _valueOf(h)!],
              dates: [for (final h in shown) h.date],
              firstOrdinal: firstOrdinal,
              selectedIndex: selectedIndex >= 0 ? selectedIndex : null,
              onSelected: (i) => setState(() => _selectedId = shown[i].executionId),
            ),
            const SizedBox(height: 12),
            PerformanceChartLegend(showAverage: shown.length >= 4),
          ],

          if (selected != null) ...[
            const SizedBox(height: 14),
            _SelectedExecution(
              execution: selected,
              ordinal: stats.ordinalOf(selected.executionId) ?? 0,
              value: _valueOf(selected)!,
              isCurrent: selected.executionId == widget.currentExecutionId,
              onOpen: widget.onOpen == null || selected.executionId == widget.currentExecutionId
                  ? null
                  : () => widget.onOpen!(selected),
              now: widget.now,
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

BoxDecoration _cardDecoration(AppColors colors) => BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colors.border.withValues(alpha: 0.6)),
    );

// -------------------------------------------------------
// RESUMO (indicadores)
// -------------------------------------------------------

class _Summary extends StatelessWidget {
  final EvolutionStats stats;

  const _Summary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final best = stats.best!;
    final recent = stats.recentAverage ?? 0;
    final delta = stats.averageDelta;

    final (trendIcon, trendText) = switch (stats.trend) {
      EvolutionTrend.improving => (Icons.trending_up_rounded, 'Em evolução'),
      EvolutionTrend.declining => (Icons.trending_down_rounded, 'Em queda'),
      EvolutionTrend.stable => (Icons.trending_flat_rounded, 'Estável'),
      EvolutionTrend.unknown => (Icons.timeline_rounded, 'Primeira execução'),
    };

    final tiles = [
      _Tile(
        icon: Icons.emoji_events_rounded,
        iconColor: AppColors.gold,
        label: 'Melhor pontuação',
        value: '${best.score.round()}%',
        footer: Text(
          'Conceito ${PerformanceScoreCard.grade(best.score)} · ${_shortDate(best.date)}',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ),
      _Tile(
        icon: trendIcon,
        iconColor: colors.primarySoft,
        label: stats.averageWindow > 1
            ? 'Média das últimas ${stats.averageWindow}'
            : 'Última execução',
        value: '${recent.round()}%',
        footer: delta == null
            ? Text(trendText, style: TextStyle(color: colors.textMuted, fontSize: 12))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DeltaLabel(delta: delta, suffix: ' pts'),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      trendText,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
      _Tile(
        icon: Icons.replay_rounded,
        iconColor: colors.primarySoft,
        label: 'Execuções',
        value: '${stats.count}',
        footer: Text(
          '${stats.completedCount} ${stats.completedCount == 1 ? 'concluída' : 'concluídas'}',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ),
      _Tile(
        icon: Icons.speed_rounded,
        iconColor: colors.primarySoft,
        label: 'Maior andamento',
        value: stats.maxBpm != null ? '${stats.maxBpm} BPM' : '--',
        footer: Text(
          stats.maxBpmCompleted ? 'em música concluída' : 'em execução interrompida',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
        );
      },
    );
  }

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget footer;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          footer,
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// GRÁFICO BLOQUEADO (antes da 10ª execução – RFA11)
// -------------------------------------------------------

class _ChartLocked extends StatelessWidget {
  final int count;

  const _ChartLocked({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const minimum = EvolutionPanel.chartMinimum;
    final missing = minimum - count;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(colors),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.show_chart_rounded, color: colors.primarySoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gráfico de evolução na $minimumª execução',
                  style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  missing == 1
                      ? 'Falta 1 execução desta música para liberar o gráfico.'
                      : 'Faltam $missing execuções desta música para liberar o gráfico.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: count / minimum,
                          minHeight: 8,
                          backgroundColor: colors.subtle,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$count/$minimum',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// EXECUÇÃO SELECIONADA NO GRÁFICO
// -------------------------------------------------------

class _SelectedExecution extends StatelessWidget {
  final PerformanceHistory execution;
  final int ordinal;
  final double value;
  final bool isCurrent;
  final VoidCallback? onOpen;
  final DateTime? now;

  const _SelectedExecution({
    required this.execution,
    required this.ordinal,
    required this.value,
    required this.isCurrent,
    required this.onOpen,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$ordinalª execução · ${value.round()}%',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatExecutionDate(execution.date, now: now)} · '
                  '${execution.completed ? 'concluída' : 'interrompida'} · ${execution.bpm} BPM',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('Aberta', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            )
          else if (onOpen != null)
            TextButton.icon(
              onPressed: onOpen,
              style: TextButton.styleFrom(foregroundColor: colors.isDark ? colors.primarySoft : AppColors.accent),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ver execução'),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.deepPurple : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

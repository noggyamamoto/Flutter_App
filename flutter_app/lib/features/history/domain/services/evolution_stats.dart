import '../entities/performance_history.dart';

// Resumo da evolução em uma música (aba Evolução), como nos apps de prática
// que acompanham o progresso: melhor pontuação, média recente comparada com
// as execuções anteriores, quantidade de execuções e maior andamento.
class EvolutionStats {
  // Execuções da mais antiga para a mais recente.
  final List<PerformanceHistory> chronological;

  final int count;
  final int completedCount;

  // Melhor execução (maior pontuação; no empate, a mais recente).
  final PerformanceHistory? best;

  // Última execução e a anterior a ela.
  final PerformanceHistory? latest;
  final PerformanceHistory? previous;

  // Média das últimas execuções (até 5) e das que vieram antes delas
  // (mesma quantidade). Sem execuções anteriores, previousAverage é null.
  final double? recentAverage;
  final double? previousAverage;
  final int averageWindow;

  // Maior andamento de uma música concluída (ou tocado, se nenhuma foi).
  final int? maxBpm;
  final bool maxBpmCompleted;

  const EvolutionStats._({
    required this.chronological,
    required this.count,
    required this.completedCount,
    required this.best,
    required this.latest,
    required this.previous,
    required this.recentAverage,
    required this.previousAverage,
    required this.averageWindow,
    required this.maxBpm,
    required this.maxBpmCompleted,
  });

  // `history` em qualquer ordem.
  factory EvolutionStats.from(List<PerformanceHistory> history) {
    final ordered = [...history]..sort((a, b) => a.date.compareTo(b.date));
    final count = ordered.length;

    PerformanceHistory? best;
    for (final h in ordered) {
      if (best == null || h.score >= best.score) best = h;
    }

    // Média das últimas `window` execuções contra as `window` anteriores.
    final window = count >= 2 ? (count ~/ 2).clamp(1, 5) : count;
    double? mean(Iterable<PerformanceHistory> items) {
      final list = items.toList();
      if (list.isEmpty) return null;
      return list.fold<double>(0, (sum, h) => sum + h.score) / list.length;
    }

    final recent = ordered.reversed.take(window);
    final before = ordered.reversed.skip(window).take(window);

    final completed = ordered.where((h) => h.completed).toList();
    int bpmOf(PerformanceHistory h) => h.finalBpm ?? h.bpm;
    final bpmSource = completed.isNotEmpty ? completed : ordered;
    final maxBpm = bpmSource.isEmpty
        ? null
        : bpmSource.map(bpmOf).reduce((a, b) => a > b ? a : b);

    return EvolutionStats._(
      chronological: ordered,
      count: count,
      completedCount: completed.length,
      best: best,
      latest: count > 0 ? ordered.last : null,
      previous: count > 1 ? ordered[count - 2] : null,
      recentAverage: mean(recent),
      previousAverage: count >= 2 ? mean(before) : null,
      averageWindow: window,
      maxBpm: maxBpm != null && maxBpm > 0 ? maxBpm : null,
      maxBpmCompleted: completed.isNotEmpty,
    );
  }

  // Diferença (em pontos) entre a média recente e a anterior.
  double? get averageDelta {
    final recent = recentAverage;
    final before = previousAverage;
    if (recent == null || before == null) return null;
    return recent - before;
  }

  // Tendência: mais de 2 pontos de diferença entre as médias.
  EvolutionTrend get trend {
    final delta = averageDelta;
    if (delta == null) return EvolutionTrend.unknown;
    if (delta > 2) return EvolutionTrend.improving;
    if (delta < -2) return EvolutionTrend.declining;
    return EvolutionTrend.stable;
  }

  // Número da execução (1 = a primeira) pelo id do documento.
  int? ordinalOf(String executionId) {
    final index = chronological.indexWhere((h) => h.executionId == executionId);
    return index < 0 ? null : index + 1;
  }

  // Execução anterior (cronologicamente) à informada.
  PerformanceHistory? previousOf(PerformanceHistory execution) {
    final index = chronological.indexWhere((h) => h.executionId == execution.executionId);
    return index > 0 ? chronological[index - 1] : null;
  }

  // Média móvel (janela de `window` execuções, centrada no fim): suaviza as
  // oscilações de uma execução para outra e mostra a tendência no gráfico.
  static List<double> movingAverage(List<double> values, {int window = 3}) {
    final result = <double>[];
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= window) sum -= values[i - window];
      final n = i + 1 < window ? i + 1 : window;
      result.add(sum / n);
    }
    return result;
  }
}

enum EvolutionTrend { improving, stable, declining, unknown }

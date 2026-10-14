import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../configuration/presentation/providers/configuration_provider.dart';
import '../../../performance/presentation/pages/performance_result_page.dart';
import '../../../score/domain/services/score_analyzer.dart';
import '../../../score/presentation/providers/score_provider.dart';
import '../../../songs/domain/entities/song.dart';
import '../../domain/entities/performance_history.dart';

// Execução anterior aberta pelo histórico: carrega a partitura (dividida
// nos mesmos trechos da execução) e mostra a mesma tela do fim da execução,
// com as notas coloridas e a avaliação salvas naquela execução.
class PastPerformancePage extends ConsumerStatefulWidget {
  final Song song;
  final PerformanceHistory execution;

  const PastPerformancePage({
    super.key,
    required this.song,
    required this.execution,
  });

  @override
  ConsumerState<PastPerformancePage> createState() => _PastPerformancePageState();
}

class _PastPerformancePageState extends ConsumerState<PastPerformancePage> {
  late final Future<ScoreStructure?> _structure = _load();

  Future<ScoreStructure?> _load() async {
    try {
      // Partitura em cache: reabrir é instantâneo.
      final score = await ref
          .read(getMusicScoreProvider)
          .firstAvailable(widget.song.partituraCandidates);
      final measuresPerPhrase = widget.execution.measuresPerPhrase ??
          ref.read(configurationProvider).measuresPerPhrase;
      return ref.read(scoreAnalyzerProvider).analyze(
            score,
            measuresPerPhrase: measuresPerPhrase,
          );
    } catch (_) {
      // Sem a partitura, o resumo é exibido sem as notas.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScoreStructure?>(
      future: _structure,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: context.colors.background,
            body: const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          );
        }
        return PerformanceResultPage.fromHistory(
          song: widget.song,
          execution: widget.execution,
          structure: snapshot.data,
        );
      },
    );
  }
}

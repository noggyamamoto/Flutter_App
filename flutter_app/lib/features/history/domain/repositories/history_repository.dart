import '../entities/performance_history.dart';
import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';

abstract class HistoryRepository {

  // Recupera o histórico de uma música.
  Future<List<PerformanceHistory>> getHistory({
    required String userId,
    required String songId,
  });

  // Salva uma execução.
  Future<String> savePerformance({
    required String userId,
    required String songId,
    required int bpmInicial,
    required double pontuacaoFinal,
    required String status,
    double? pontuacaoAltura,
    double? pontuacaoRitmo,
    int? bpmFinal,
    int? notasTocadas,
    int? notasCorretas,
    int? notasEsperadas,
    int? notasExtras,
    int? maiorSequencia,
    int? compassosPorTrecho,
    List<PhraseResult>? trechos,
    Map<int, NoteFeedback>? resultadoNotas,
  });

  // Músicas tocadas recentemente (mais recentes primeiro).
  Future<List<String>> getRecentSongIds({
    required String userId,
    int limit,
  });
}

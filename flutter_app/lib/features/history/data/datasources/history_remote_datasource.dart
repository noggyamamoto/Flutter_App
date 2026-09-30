import '../models/performance_history_model.dart';

abstract class HistoryRemoteDataSource {

  // Busca o histórico de execuções
  // de uma determinada música e usuário.
  Future<List<PerformanceHistoryModel>> getHistory({
    required String userId,
    required String songId,
  });

  // Salva uma nova execução no Firestore.
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
  });

  // IDs das músicas tocadas recentemente pelo usuário.
  Future<List<String>> getRecentSongIds({
    required String userId,
    int limit,
  });
}

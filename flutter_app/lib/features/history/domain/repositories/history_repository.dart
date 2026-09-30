import '../entities/performance_history.dart';

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
  });

  // Músicas tocadas recentemente (mais recentes primeiro).
  Future<List<String>> getRecentSongIds({
    required String userId,
    int limit,
  });
}

import '../entities/performance_history.dart';
import '../repositories/history_repository.dart';

class GetPerformanceHistory {

  // Repositório responsável pelos dados.
  final HistoryRepository repository;

  GetPerformanceHistory(
    this.repository,
  );

  // Executa a busca do histórico.
  Future<List<PerformanceHistory>> call({
    required String userId,
    required String songId,
  }) {

    return repository.getHistory(
      userId: userId,
      songId: songId,
    );
  }
}
import '../../domain/entities/performance_history.dart';
import '../../domain/repositories/history_repository.dart';

import '../datasources/history_remote_datasource.dart';

class HistoryRepositoryImpl
    implements HistoryRepository {

  // Fonte responsável pelo acesso ao Firestore.
  final HistoryRemoteDataSource dataSource;

  HistoryRepositoryImpl(
    this.dataSource,
  );

  @override
  Future<List<PerformanceHistory>> getHistory({
    required String userId,
    required String songId,
  }) async {

    // Busca os Models na fonte de dados.
    final models = await dataSource.getHistory(
      userId: userId,
      songId: songId,
    );

    // Converte Models para Entities.
    return models
        .map(
          (model) => model.toEntity(),
        )
        .toList();
  }

  @override
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
  }) {

    // Delega o salvamento para o DataSource.
    return dataSource.savePerformance(
      userId: userId,
      songId: songId,
      bpmInicial: bpmInicial,
      pontuacaoFinal: pontuacaoFinal,
      status: status,
      pontuacaoAltura: pontuacaoAltura,
      pontuacaoRitmo: pontuacaoRitmo,
      bpmFinal: bpmFinal,
      notasTocadas: notasTocadas,
      notasCorretas: notasCorretas,
    );
  }

  @override
  Future<List<String>> getRecentSongIds({
    required String userId,
    int limit = 3,
  }) {
    return dataSource.getRecentSongIds(
      userId: userId,
      limit: limit,
    );
  }
}

import '../repositories/history_repository.dart';

class SavePerformance {

  // Repositório responsável pelo armazenamento.
  final HistoryRepository repository;

  SavePerformance(
    this.repository,
  );

  // Salva uma execução.
  Future<String> call({
    required String userId,
    required String songId,
    required int bpmInicial,
    required double pontuacaoFinal,
    required String status,
  }) {

    return repository.savePerformance(
      userId: userId,
      songId: songId,
      bpmInicial: bpmInicial,
      pontuacaoFinal: pontuacaoFinal,
      status: status,
    );
  }
}
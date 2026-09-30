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
    double? pontuacaoAltura,
    double? pontuacaoRitmo,
    int? bpmFinal,
    int? notasTocadas,
    int? notasCorretas,
  }) {

    return repository.savePerformance(
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
}
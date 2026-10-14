import '../repositories/history_repository.dart';
import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';

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
    int? notasEsperadas,
    int? notasExtras,
    int? maiorSequencia,
    int? compassosPorTrecho,
    List<PhraseResult>? trechos,
    Map<int, NoteFeedback>? resultadoNotas,
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
      notasEsperadas: notasEsperadas,
      notasExtras: notasExtras,
      maiorSequencia: maiorSequencia,
      compassosPorTrecho: compassosPorTrecho,
      trechos: trechos,
      resultadoNotas: resultadoNotas,
    );
  }
}
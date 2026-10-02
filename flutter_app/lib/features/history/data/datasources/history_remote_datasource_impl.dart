import 'package:cloud_firestore/cloud_firestore.dart';

import 'history_remote_datasource.dart';
import '../models/performance_history_model.dart';

class HistoryRemoteDataSourceImpl
    implements HistoryRemoteDataSource {

  // Instância do Firestore.
  final FirebaseFirestore firestore;

  HistoryRemoteDataSourceImpl(
    this.firestore,
  );

  @override
  Future<List<PerformanceHistoryModel>> getHistory({
    required String userId,
    required String songId,
  }) async {

    // Busca as execuções no Firestore.
    //
    // Somente filtros de igualdade: combinados com orderBy('dataHora') eles
    // exigiriam um índice composto (idUsuario + idPartitura + dataHora) que
    // o projeto não tem, e a consulta falhava (FAILED_PRECONDITION) – era o
    // erro da aba Evolução. O filtro por idUsuario também é exigido pela
    // regra de leitura de "execucoes".
    final snapshot = await firestore
        .collection('execucoes')

        // Filtra pelo usuário logado.
        .where(
          'idUsuario',
          isEqualTo: userId,
        )

        // Filtra pela música atual.
        .where(
          'idPartitura',
          isEqualTo: songId,
        )

        // Executa a consulta.
        .get();

    // Converte cada documento do Firestore
    // para PerformanceHistoryModel.
    final history = snapshot.docs.map((doc) {

      // Copia os dados do documento.
      final data = <String, dynamic>{
        // Adiciona o ID do documento.
        'executionId': doc.id,

        // Adiciona os demais campos.
        ...doc.data(),
      };

      // Converte os dados para o Model.
      return PerformanceHistoryModel.fromMap(
        data,
      );

    }).toList();

    // Mais recentes primeiro (ordenação feita no app).
    history.sort((a, b) => b.date.compareTo(a.date));

    return history;
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
  }) async {

    // Cria um novo documento dentro de execucoes.
    final document = await firestore
        .collection('execucoes')
        .add({

      // Usuário que realizou a execução.
      'idUsuario': userId,

      // Música executada.
      'idPartitura': songId,

      // Data e hora geradas pelo próprio servidor.
      'dataHora':
          FieldValue.serverTimestamp(),

      // BPM utilizado.
      'bpmInicial': bpmInicial,

      // Pontuação obtida.
      'pontuacaoFinal': pontuacaoFinal,

      // Estado da execução.
      'status': status,

      // Detalhes da avaliação (RU13).
      'pontuacaoAltura': ?pontuacaoAltura,
      'pontuacaoRitmo': ?pontuacaoRitmo,
      'bpmFinal': ?bpmFinal,
      'notasTocadas': ?notasTocadas,
      'notasCorretas': ?notasCorretas,
    });

    // Retorna o ID criado pelo Firestore.
    return document.id;
  }

  @override
  Future<List<String>> getRecentSongIds({
    required String userId,
    int limit = 3,
  }) async {

    // Busca as execuções do usuário. A ordenação é feita no app para
    // não exigir um índice composto no Firestore.
    final snapshot = await firestore
        .collection('execucoes')
        .where(
          'idUsuario',
          isEqualTo: userId,
        )
        .get();

    final executions = snapshot.docs
        .map((doc) => PerformanceHistoryModel.fromMap({
              'executionId': doc.id,
              ...doc.data(),
            }))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Mantém apenas a primeira ocorrência de cada música.
    final ids = <String>[];
    for (final execution in executions) {
      if (!ids.contains(execution.songId)) ids.add(execution.songId);
      if (ids.length >= limit) break;
    }
    return ids;
  }
}

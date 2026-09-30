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

        // Mais recentes primeiro.
        .orderBy(
          'dataHora',
          descending: true,
        )

        // Executa a consulta.
        .get();

    // Converte cada documento do Firestore
    // para PerformanceHistoryModel.
    return snapshot.docs.map((doc) {

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
  }

  @override
  Future<String> savePerformance({
    required String userId,
    required String songId,
    required int bpmInicial,
    required double pontuacaoFinal,
    required String status,
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
    });

    // Retorna o ID criado pelo Firestore.
    return document.id;
  }
}
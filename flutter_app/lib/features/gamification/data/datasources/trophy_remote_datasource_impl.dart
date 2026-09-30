import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_trophy.dart';
import '../../domain/repositories/trophy_repository.dart';
import '../models/trophy_model.dart';
import 'trophy_remote_datasource.dart';

// Troféus no Firestore:
//  - trofeus/{id}                      catálogo (opcional)
//  - usuarios/{uid}/trofeus/{idTrofeu} conquistas do usuário
//  - execucoes                         histórico usado nos critérios
class TrophyRemoteDataSourceImpl implements TrophyRemoteDataSource {
  final FirebaseFirestore firestore;

  TrophyRemoteDataSourceImpl(this.firestore);

  @override
  Future<List<TrophyModel>> getTrophies() async {
    try {
      final snapshot = await firestore.collection('trofeus').get();
      final list = snapshot.docs
          .map((doc) => TrophyModel.fromMap({'id': doc.id, ...doc.data()}))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // Sem permissão ou sem rede: usa o catálogo padrão.
    }
    return TrophyModel.defaults;
  }

  @override
  Future<List<UserTrophyModel>> getUserTrophies(String userId) async {
    final snapshot = await firestore
        .collection('usuarios')
        .doc(userId)
        .collection('trofeus')
        .get();
    return snapshot.docs.map((doc) => UserTrophyModel.fromMap(doc.data())).toList();
  }

  @override
  Future<void> awardTrophies(String userId, List<UserTrophy> trophies) async {
    final batch = firestore.batch();
    final collection = firestore.collection('usuarios').doc(userId).collection('trofeus');
    for (final trophy in trophies) {
      batch.set(collection.doc(trophy.trophyId), {
        'idTrofeu': trophy.trophyId,
        'idPartitura': trophy.songId,
        'dataConquista': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<List<ExecutionSummary>> getExecutions(String userId) async {
    final snapshot = await firestore
        .collection('execucoes')
        .where('idUsuario', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ExecutionSummary(
        songId: data['idPartitura'] as String? ?? '',
        score: (data['pontuacaoFinal'] as num?)?.toDouble() ?? 0,
        rhythm: (data['pontuacaoRitmo'] as num?)?.toDouble(),
        completed: (data['status'] as String? ?? 'concluida') == 'concluida',
      );
    }).toList();
  }
}

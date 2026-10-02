import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_trophy.dart';
import '../../domain/repositories/trophy_repository.dart';
import '../models/trophy_model.dart';
import 'trophy_remote_datasource.dart';

// Troféus no Firestore, dentro do que as regras de segurança do projeto
// (firestore.rules) permitem:
//  - trofeus/{id}       catálogo (opcional; sem regra de leitura o app usa
//                       o catálogo padrão de TrophyModel.defaults)
//  - usuarios/{uid}     campo "trofeus": mapa idTrofeu -> conquista. As regras
//                       liberam só o próprio documento do usuário; uma
//                       subcoleção (usuarios/{uid}/trofeus) cairia na regra
//                       final, que bloqueia tudo, e a tela de troféus falhava
//  - execucoes          histórico usado nos critérios (filtrado por idUsuario,
//                       exigência da regra de leitura)
class TrophyRemoteDataSourceImpl implements TrophyRemoteDataSource {
  // Campo do documento do usuário com as conquistas.
  static const trophiesField = 'trofeus';

  final FirebaseFirestore firestore;

  TrophyRemoteDataSourceImpl(this.firestore);

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      firestore.collection('usuarios').doc(userId);

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
    final snapshot = await _userDoc(userId).get();
    final trophies = snapshot.data()?[trophiesField];
    if (trophies is! Map) return const [];
    return [
      for (final entry in trophies.entries)
        if (entry.value is Map)
          UserTrophyModel.fromMap({
            'idTrofeu': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          }),
    ];
  }

  @override
  Future<void> awardTrophies(String userId, List<UserTrophy> trophies) async {
    if (trophies.isEmpty) return;
    // merge: acrescenta as novas conquistas ao mapa sem apagar as anteriores
    // nem os demais campos do perfil.
    await _userDoc(userId).set({
      trophiesField: {
        for (final trophy in trophies)
          trophy.trophyId: {
            'idTrofeu': trophy.trophyId,
            'idPartitura': ?trophy.songId,
            'dataConquista': FieldValue.serverTimestamp(),
          },
      },
    }, SetOptions(merge: true));
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

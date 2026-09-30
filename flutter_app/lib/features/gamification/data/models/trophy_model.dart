import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/trophy.dart';
import '../../domain/entities/user_trophy.dart';

class TrophyModel {
  final String id;
  final String titulo;
  final String descricao;
  final String icone;
  final String criterio;
  final double meta;

  const TrophyModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.criterio,
    required this.meta,
  });

  factory TrophyModel.fromMap(Map<String, dynamic> map) {
    return TrophyModel(
      id: map['id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descricao: map['descricao'] as String? ?? '',
      icone: map['icone'] as String? ?? 'emoji_events',
      criterio: map['criterio'] as String? ?? 'totalPerformances',
      meta: (map['meta'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'icone': icone,
      'criterio': criterio,
      'meta': meta,
    };
  }

  Trophy toEntity() {
    return Trophy(
      id: id,
      titulo: titulo,
      descricao: descricao,
      icone: icone,
      criterio: TrophyCriterion.values.firstWhere(
        (c) => c.name == criterio,
        orElse: () => TrophyCriterion.totalPerformances,
      ),
      meta: meta,
    );
  }

  // Catálogo usado quando a coleção "trofeus" do Firestore está vazia.
  static const defaults = [
    TrophyModel(
      id: 'primeira_musica',
      titulo: 'Primeiros acordes',
      descricao: 'Conclua a sua primeira música.',
      icone: 'music_note',
      criterio: 'totalPerformances',
      meta: 1,
    ),
    TrophyModel(
      id: 'bom_ouvido',
      titulo: 'Bom ouvido',
      descricao: 'Alcance 70% de pontuação em uma música.',
      icone: 'hearing',
      criterio: 'scoreAtLeast',
      meta: 70,
    ),
    TrophyModel(
      id: 'virtuose',
      titulo: 'Virtuose',
      descricao: 'Alcance 90% de pontuação em uma música.',
      icone: 'star',
      criterio: 'scoreAtLeast',
      meta: 90,
    ),
    TrophyModel(
      id: 'metronomo_humano',
      titulo: 'Metrônomo humano',
      descricao: 'Alcance 90% de precisão rítmica.',
      icone: 'av_timer',
      criterio: 'rhythmAtLeast',
      meta: 90,
    ),
    TrophyModel(
      id: 'dedicacao',
      titulo: 'Dedicação',
      descricao: 'Toque a mesma música 10 vezes.',
      icone: 'repeat',
      criterio: 'sameSongCount',
      meta: 10,
    ),
    TrophyModel(
      id: 'explorador',
      titulo: 'Explorador',
      descricao: 'Toque 3 músicas diferentes.',
      icone: 'explore',
      criterio: 'distinctSongs',
      meta: 3,
    ),
    TrophyModel(
      id: 'desafio_aceito',
      titulo: 'Desafio aceito',
      descricao: 'Alcance 70% em uma música de nível difícil.',
      icone: 'whatshot',
      criterio: 'hardSongScore',
      meta: 70,
    ),
    TrophyModel(
      id: 'maratonista',
      titulo: 'Maratonista',
      descricao: 'Conclua 25 execuções.',
      icone: 'emoji_events',
      criterio: 'totalPerformances',
      meta: 25,
    ),
  ];
}

class UserTrophyModel {
  final String trophyId;
  final DateTime dataConquista;
  final String? songId;

  const UserTrophyModel({
    required this.trophyId,
    required this.dataConquista,
    this.songId,
  });

  factory UserTrophyModel.fromMap(Map<String, dynamic> map) {
    final timestamp = map['dataConquista'];
    return UserTrophyModel(
      trophyId: map['idTrofeu'] as String? ?? '',
      dataConquista: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      songId: map['idPartitura'] as String?,
    );
  }

  UserTrophy toEntity() => UserTrophy(
        trophyId: trophyId,
        dataConquista: dataConquista,
        songId: songId,
      );
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/performance_history.dart';

class PerformanceHistoryModel {
  // ID do documento da execução.
  final String executionId;

  // ID da partitura.
  final String songId;

  // Data e hora da execução.
  final DateTime date;

  // Pontuação final.
  final double score;

  // BPM inicial.
  final int bpm;

  // Status da execução.
  final String status;

  const PerformanceHistoryModel({
    required this.executionId,
    required this.songId,
    required this.date,
    required this.score,
    required this.bpm,
    required this.status,
  });

  // Converte os dados vindos do Firestore para o Model.
  factory PerformanceHistoryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    // Recupera o valor do campo dataHora.
    final timestamp = map['dataHora'];

    // Se o Firestore enviou um Timestamp,
    // convertemos para DateTime.
    final date = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.now();

    return PerformanceHistoryModel(
      // ID do documento.
      executionId:
          map['executionId'] as String? ?? '',

      // ID da partitura.
      songId:
          map['idPartitura'] as String? ?? '',

      // Data da execução.
      date: date,

      // Pontuação.
      score: (map['pontuacaoFinal'] as num?)
              ?.toDouble() ??
          0,

      // BPM inicial.
      bpm: map['bpmInicial'] as int? ?? 0,

      // Status.
      status:
          map['status'] as String? ?? '',
    );
  }

  // Converte o Model para a Entity.
  PerformanceHistory toEntity() {
    return PerformanceHistory(
      executionId: executionId,
      songId: songId,
      date: date,
      score: score,
      bpm: bpm,
      status: status,
    );
  }
}
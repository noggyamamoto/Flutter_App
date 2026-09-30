class PerformanceHistory {
  // ID do documento da execução no Firestore.
  final String executionId;

  // ID da partitura executada.
  final String songId;

  // Data e hora em que a execução aconteceu.
  final DateTime date;

  // Pontuação final obtida na execução.
  final double score;

  // BPM usado no início da execução.
  final int bpm;

  // Status da execução.
  final String status;

  const PerformanceHistory({
    required this.executionId,
    required this.songId,
    required this.date,
    required this.score,
    required this.bpm,
    required this.status,
  });
}
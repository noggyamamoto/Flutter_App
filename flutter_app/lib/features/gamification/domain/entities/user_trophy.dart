// Troféu conquistado por um usuário.
class UserTrophy {
  final String trophyId;
  final DateTime dataConquista;

  // Música em que o troféu foi conquistado (quando aplicável).
  final String? songId;

  const UserTrophy({
    required this.trophyId,
    required this.dataConquista,
    this.songId,
  });
}

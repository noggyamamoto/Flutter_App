import '../entities/trophy.dart';
import '../entities/user_trophy.dart';

// Execução resumida para o cálculo dos troféus.
class ExecutionSummary {
  final String songId;
  final double score;
  final double? rhythm;
  final bool completed;

  const ExecutionSummary({
    required this.songId,
    required this.score,
    required this.rhythm,
    required this.completed,
  });
}

abstract class TrophyRepository {
  // Catálogo de troféus.
  Future<List<Trophy>> getTrophies();

  // Troféus já conquistados pelo usuário.
  Future<List<UserTrophy>> getUserTrophies(String userId);

  // Registra novas conquistas.
  Future<void> awardTrophies(String userId, List<UserTrophy> trophies);

  // Execuções do usuário.
  Future<List<ExecutionSummary>> getExecutions(String userId);
}

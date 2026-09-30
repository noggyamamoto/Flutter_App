import '../../domain/entities/user_trophy.dart';
import '../../domain/repositories/trophy_repository.dart';
import '../models/trophy_model.dart';

abstract class TrophyRemoteDataSource {
  Future<List<TrophyModel>> getTrophies();

  Future<List<UserTrophyModel>> getUserTrophies(String userId);

  Future<void> awardTrophies(String userId, List<UserTrophy> trophies);

  Future<List<ExecutionSummary>> getExecutions(String userId);
}

import '../../domain/entities/trophy.dart';
import '../../domain/entities/user_trophy.dart';
import '../../domain/repositories/trophy_repository.dart';
import '../datasources/trophy_remote_datasource.dart';

class TrophyRepositoryImpl implements TrophyRepository {
  final TrophyRemoteDataSource dataSource;

  TrophyRepositoryImpl(this.dataSource);

  @override
  Future<List<Trophy>> getTrophies() async {
    final models = await dataSource.getTrophies();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<UserTrophy>> getUserTrophies(String userId) async {
    final models = await dataSource.getUserTrophies(userId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> awardTrophies(String userId, List<UserTrophy> trophies) {
    return dataSource.awardTrophies(userId, trophies);
  }

  @override
  Future<List<ExecutionSummary>> getExecutions(String userId) {
    return dataSource.getExecutions(userId);
  }
}

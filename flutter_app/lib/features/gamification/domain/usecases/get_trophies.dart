import '../entities/trophy_progress.dart';
import '../repositories/trophy_repository.dart';
import 'check_trophies.dart';

// Lista os troféus com a situação do usuário.
class GetTrophies {
  final TrophyRepository repository;

  GetTrophies(this.repository);

  Future<List<TrophyProgress>> call({
    required String userId,
    required Set<String> hardSongIds,
  }) async {
    final trophies = await repository.getTrophies();
    final conquered = await repository.getUserTrophies(userId);
    final executions = await repository.getExecutions(userId);
    final stats = CheckTrophies.statsOf(executions, hardSongIds);

    return trophies.map((trophy) {
      final conquest = conquered.where((c) => c.trophyId == trophy.id).firstOrNull;
      return TrophyProgress(
        trophy: trophy,
        conquest: conquest,
        progress: conquest != null ? 1 : CheckTrophies.progressOf(trophy, stats),
      );
    }).toList();
  }
}

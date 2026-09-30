import '../entities/trophy.dart';
import '../entities/trophy_progress.dart';
import '../entities/user_trophy.dart';
import '../repositories/trophy_repository.dart';

// Verifica, após uma execução, se o usuário conquistou novos troféus
// (RFA10) e registra as conquistas.
class CheckTrophies {
  final TrophyRepository repository;

  CheckTrophies(this.repository);

  // Retorna somente os troféus conquistados agora.
  Future<List<Trophy>> call({
    required String userId,
    required String songId,
    required Set<String> hardSongIds,
  }) async {
    final trophies = await repository.getTrophies();
    final conquered = (await repository.getUserTrophies(userId))
        .map((t) => t.trophyId)
        .toSet();
    final executions = await repository.getExecutions(userId);
    final stats = statsOf(executions, hardSongIds);

    final unlocked = trophies
        .where((t) => !conquered.contains(t.id) && progressOf(t, stats) >= 1)
        .toList();

    if (unlocked.isNotEmpty) {
      final now = DateTime.now();
      await repository.awardTrophies(
        userId,
        [
          for (final trophy in unlocked)
            UserTrophy(trophyId: trophy.id, dataConquista: now, songId: songId),
        ],
      );
    }
    return unlocked;
  }

  static PerformanceStats statsOf(
    List<ExecutionSummary> executions,
    Set<String> hardSongIds,
  ) {
    final completed = executions.where((e) => e.completed).toList();
    final perSong = <String, int>{};
    var bestScore = 0.0;
    var bestRhythm = 0.0;
    var bestHard = 0.0;

    for (final execution in completed) {
      perSong[execution.songId] = (perSong[execution.songId] ?? 0) + 1;
      if (execution.score > bestScore) bestScore = execution.score;
      if ((execution.rhythm ?? 0) > bestRhythm) bestRhythm = execution.rhythm!;
      if (hardSongIds.contains(execution.songId) && execution.score > bestHard) {
        bestHard = execution.score;
      }
    }

    return PerformanceStats(
      completed: completed.length,
      perSong: perSong,
      bestScore: bestScore,
      bestRhythm: bestRhythm,
      bestHardScore: bestHard,
    );
  }

  static double progressOf(Trophy trophy, PerformanceStats stats) {
    if (trophy.meta <= 0) return 1;
    final value = switch (trophy.criterio) {
      TrophyCriterion.totalPerformances => stats.completed.toDouble(),
      TrophyCriterion.scoreAtLeast => stats.bestScore,
      TrophyCriterion.rhythmAtLeast => stats.bestRhythm,
      TrophyCriterion.sameSongCount => stats.maxSameSong.toDouble(),
      TrophyCriterion.distinctSongs => stats.distinctSongs.toDouble(),
      TrophyCriterion.hardSongScore => stats.bestHardScore,
    };
    return (value / trophy.meta).clamp(0.0, 1.0);
  }
}

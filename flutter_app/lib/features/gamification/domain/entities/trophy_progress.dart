import 'trophy.dart';
import 'user_trophy.dart';

// Troféu com a situação do usuário.
class TrophyProgress {
  final Trophy trophy;
  final UserTrophy? conquest;

  // Progresso de 0 a 1 em direção à meta.
  final double progress;

  const TrophyProgress({
    required this.trophy,
    required this.conquest,
    required this.progress,
  });

  bool get unlocked => conquest != null;
}

// Resumo das execuções do usuário usado para avaliar os critérios.
class PerformanceStats {
  // Execuções concluídas.
  final int completed;

  // Execuções concluídas por música.
  final Map<String, int> perSong;

  // Maiores pontuações.
  final double bestScore;
  final double bestRhythm;

  // Maior pontuação em músicas difíceis.
  final double bestHardScore;

  const PerformanceStats({
    required this.completed,
    required this.perSong,
    required this.bestScore,
    required this.bestRhythm,
    required this.bestHardScore,
  });

  int get distinctSongs => perSong.length;

  int get maxSameSong =>
      perSong.values.fold(0, (max, count) => count > max ? count : max);
}

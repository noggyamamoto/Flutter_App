// Critérios para conquistar um troféu.
enum TrophyCriterion {
  // Concluir execuções (meta = quantidade).
  totalPerformances,

  // Pontuação geral mínima em uma execução concluída (meta = %).
  scoreAtLeast,

  // Precisão rítmica mínima em uma execução concluída (meta = %).
  rhythmAtLeast,

  // Tocar a mesma música várias vezes (meta = quantidade).
  sameSongCount,

  // Tocar músicas diferentes (meta = quantidade).
  distinctSongs,

  // Pontuação mínima em uma música de nível difícil (meta = %).
  hardSongScore,
}

// Troféu da gamificação (RU15).
class Trophy {
  final String id;
  final String titulo;
  final String descricao;

  // Nome do ícone (ver TrophyIcons na página de troféus).
  final String icone;

  final TrophyCriterion criterio;
  final double meta;

  const Trophy({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.criterio,
    required this.meta,
  });
}

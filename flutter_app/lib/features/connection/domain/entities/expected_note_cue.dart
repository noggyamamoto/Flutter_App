// Nota esperada da partitura enviada ao dispositivo, somente para o monitor
// da execução no terminal serial (quem avalia é o app).
class ExpectedNoteCue {
  // Posição na lista de notas esperadas.
  final int index;

  final int midi;

  // Início e duração no relógio da sessão (andamento atual).
  final int onsetMs;
  final int durationMs;

  // Duração em semínimas (figura: 1 = semínima, 0.5 = colcheia...).
  final double durationBeats;

  const ExpectedNoteCue({
    required this.index,
    required this.midi,
    required this.onsetMs,
    required this.durationMs,
    required this.durationBeats,
  });
}

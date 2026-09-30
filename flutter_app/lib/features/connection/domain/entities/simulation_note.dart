// Nota que o dispositivo simulado "tocará" no modo demonstração.
class SimulationNote {
  final int midi;
  final int onsetMs;
  final int durationMs;

  const SimulationNote({
    required this.midi,
    required this.onsetMs,
    required this.durationMs,
  });
}

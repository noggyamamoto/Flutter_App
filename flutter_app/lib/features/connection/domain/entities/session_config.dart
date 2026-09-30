// Parâmetros enviados ao dispositivo no início de uma execução.
class SessionConfig {
  // Andamento do metrônomo (batidas por minuto).
  final int bpm;

  // Tempos por compasso (2 = binário, 3 = ternário, 4 = quaternário).
  final int beatsPerBar;

  // Compassos de contagem antes da música (RFA05).
  final int countInBars;

  // Metrônomo sonoro e visual no dispositivo (RFE02 / RFE03).
  final bool metronomeSound;
  final bool metronomeVisual;

  const SessionConfig({
    required this.bpm,
    required this.beatsPerBar,
    this.countInBars = 2,
    this.metronomeSound = true,
    this.metronomeVisual = true,
  });

  // Duração de uma batida em milissegundos.
  double get beatMs => 60000 / bpm;

  // Duração da contagem de entrada em milissegundos.
  double get countInMs => countInBars * beatsPerBar * beatMs;
}

// Eventos enviados pelo dispositivo durante a conexão.
//
// Os tempos (timeMs) usam o relógio da sessão: 0 = início da contagem
// de entrada (momento em que o dispositivo recebeu o comando de início).
sealed class DeviceEvent {
  const DeviceEvent();
}

// Início de uma nota detectada pelo microfone.
class NotePlayedEvent extends DeviceEvent {
  final int midi;
  final double frequency;
  final double confidence;
  final int timeMs;

  const NotePlayedEvent({
    required this.midi,
    required this.frequency,
    required this.confidence,
    required this.timeMs,
  });
}

// Fim de uma nota detectada.
class NoteReleasedEvent extends DeviceEvent {
  final int midi;
  final int durationMs;
  final int timeMs;

  const NoteReleasedEvent({
    required this.midi,
    required this.durationMs,
    required this.timeMs,
  });
}

// Batida do metrônomo do dispositivo.
class BeatEvent extends DeviceEvent {
  final int beatInBar;
  final bool countIn;
  final int barIndex;
  final int bpm;
  final int timeMs;

  const BeatEvent({
    required this.beatInBar,
    required this.countIn,
    required this.barIndex,
    required this.bpm,
    required this.timeMs,
  });
}

// Estado periódico (resposta ao heartbeat).
class DeviceStatusEvent extends DeviceEvent {
  final int rssi;
  final double noiseFloorDb;

  const DeviceStatusEvent({
    required this.rssi,
    required this.noiseFloorDb,
  });
}

// O dispositivo parou de responder.
class ConnectionLostEvent extends DeviceEvent {
  const ConnectionLostEvent();
}

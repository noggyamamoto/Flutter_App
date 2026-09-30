import '../../domain/entities/device_event.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/simulation_note.dart';
import '../models/device_model.dart';

abstract class ConnectionRemoteDataSource {
  // Indica se o transporte está disponível nesta plataforma.
  bool get isSupported;

  // Busca dispositivos por broadcast (ou em um IP específico).
  Future<List<DeviceModel>> discover({
    Duration timeout,
    String? address,
  });

  // Pareia com o dispositivo (aguarda a confirmação).
  Future<void> connect(DeviceModel device);

  // Encerra a comunicação.
  Future<void> disconnect();

  // Eventos recebidos do dispositivo pareado.
  Stream<DeviceEvent> get events;

  // Comandos da execução.
  Future<void> startSession(SessionConfig config);
  Future<void> stopSession();
  Future<void> setTempo(int bpm);
  Future<void> configure(SessionConfig config);

  // Usado apenas pelo dispositivo simulado.
  void scheduleSimulation(List<SimulationNote> notes);
}

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
  // Novo andamento a partir da batida `atBeat` (índice desde o início da
  // sessão, contagem incluída). 0 = na próxima batida.
  Future<void> setTempo(int bpm, {int atBeat = 0});
  Future<void> configure(SessionConfig config);

  // Usado apenas pelo dispositivo simulado.
  void scheduleSimulation(List<SimulationNote> notes);
}

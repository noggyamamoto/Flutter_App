import '../entities/device.dart';
import '../entities/device_event.dart';
import '../entities/session_config.dart';
import '../entities/simulation_note.dart';

abstract class ConnectionRepository {
  // Busca dispositivos ativos na rede (RFA01).
  Future<List<Device>> getDevices({Duration timeout, String? address});

  // Pareia com o dispositivo escolhido (RU02).
  Future<void> connect(Device device);

  // Encerra a comunicação de forma segura (RU17).
  Future<void> disconnect();

  // Dispositivo virtual do modo demonstração.
  Device get simulatedDevice;

  // Indica se a plataforma permite conexão por rede (falso na web).
  bool get isNetworkSupported;

  // Dispositivo pareado atualmente.
  Device? get connectedDevice;

  // Eventos recebidos do dispositivo.
  Stream<DeviceEvent> get events;

  // Controle da execução.
  Future<void> startSession(SessionConfig config);
  Future<void> stopSession();
  // Novo andamento a partir da batida `atBeat` (índice desde o início da
  // sessão, contagem incluída). 0 = na próxima batida.
  Future<void> setTempo(int bpm, {int atBeat = 0});
  Future<void> configure(SessionConfig config);

  // Informa ao dispositivo simulado quais notas tocar (modo demonstração).
  void scheduleSimulation(List<SimulationNote> notes);
}

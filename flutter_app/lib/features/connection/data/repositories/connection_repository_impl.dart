import 'dart:async';

import '../../domain/entities/device.dart';
import '../../domain/entities/device_event.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/simulation_note.dart';
import '../../domain/repositories/connection_repository.dart';
import '../datasources/connection_remote_datasource.dart';
import '../models/device_model.dart';

class ConnectionRepositoryImpl implements ConnectionRepository {
  // Dispositivo real (UDP).
  final ConnectionRemoteDataSource remote;

  // Dispositivo virtual (modo demonstração).
  final ConnectionRemoteDataSource simulated;

  final _events = StreamController<DeviceEvent>.broadcast();
  final List<StreamSubscription<DeviceEvent>> _subscriptions = [];

  // Modelos encontrados na última busca (id -> model).
  final Map<String, DeviceModel> _known = {};

  ConnectionRemoteDataSource? _active;
  Device? _connected;

  ConnectionRepositoryImpl({
    required this.remote,
    required this.simulated,
  }) {
    // Reencaminha somente os eventos da fonte ativa.
    for (final source in [remote, simulated]) {
      _subscriptions.add(
        source.events.listen((event) {
          if (!identical(source, _active)) return;
          if (event is ConnectionLostEvent) {
            _connected = null;
            _active = null;
          }
          _events.add(event);
        }),
      );
    }
  }

  @override
  Device? get connectedDevice => _connected;

  @override
  Stream<DeviceEvent> get events => _events.stream;

  @override
  Future<List<Device>> getDevices({
    Duration timeout = const Duration(seconds: 3),
    String? address,
  }) async {
    final models = <DeviceModel>[];

    if (remote.isSupported) {
      models.addAll(await remote.discover(timeout: timeout, address: address));
    }

    for (final model in models) {
      _known[model.id] = model;
    }
    return models.map((m) => m.toEntity()).toList();
  }

  // Dispositivo virtual sempre disponível.
  @override
  Device get simulatedDevice {
    final models = SimulatedDeviceModels.all;
    for (final model in models) {
      _known[model.id] = model;
    }
    return models.first.toEntity();
  }

  @override
  bool get isNetworkSupported => remote.isSupported;

  @override
  Future<void> connect(Device device) async {
    if (_connected != null) await disconnect();

    final source = device.isSimulated ? simulated : remote;
    final model = _known[device.id] ??
        DeviceModel(
          id: device.id,
          name: device.name,
          address: device.address,
          port: device.port,
          firmware: device.firmware,
          rssi: device.rssi,
          state: 0,
          isSimulated: device.isSimulated,
        );

    await source.connect(model);
    _active = source;
    _connected = device;
  }

  @override
  Future<void> disconnect() async {
    final source = _active;
    _active = null;
    _connected = null;
    await source?.disconnect();
  }

  ConnectionRemoteDataSource _require() {
    final source = _active;
    if (source == null) throw Exception('Nenhum dispositivo conectado.');
    return source;
  }

  @override
  Future<void> startSession(SessionConfig config) => _require().startSession(config);

  @override
  Future<void> stopSession() async => _active?.stopSession();

  @override
  Future<void> setTempo(int bpm, {int atBeat = 0}) async =>
      _active?.setTempo(bpm, atBeat: atBeat);

  @override
  Future<void> configure(SessionConfig config) async => _active?.configure(config);

  @override
  void scheduleSimulation(List<SimulationNote> notes) {
    _active?.scheduleSimulation(notes);
  }
}

// Lista dos dispositivos virtuais oferecidos na tela de conexão.
class SimulatedDeviceModels {
  static const all = [
    DeviceModel(
      id: 'SIMULADOR',
      name: 'Simulador (modo demonstração)',
      address: '127.0.0.1',
      port: 0,
      firmware: 'virtual',
      rssi: -40,
      state: 0,
      isSimulated: true,
    ),
  ];
}

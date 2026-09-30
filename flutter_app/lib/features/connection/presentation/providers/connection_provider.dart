import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/connection_remote_datasource.dart';
import '../../data/datasources/connection_remote_datasource_impl.dart';
import '../../data/datasources/simulated_device_datasource.dart';
import '../../data/repositories/connection_repository_impl.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/device_event.dart';
import '../../domain/repositories/connection_repository.dart';
import '../../domain/usecases/connect_device.dart';
import '../../domain/usecases/disconnect_device.dart';
import '../../domain/usecases/get_devices.dart';

// ==========================================================
// DATASOURCES
// ==========================================================

final connectionRemoteDataSourceProvider =
    Provider<ConnectionRemoteDataSource>((ref) {
  final dataSource = ConnectionRemoteDataSourceImpl();
  ref.onDispose(dataSource.dispose);
  return dataSource;
});

final simulatedDeviceDataSourceProvider =
    Provider<ConnectionRemoteDataSource>((ref) {
  return SimulatedDeviceDataSource();
});

// ==========================================================
// REPOSITORY
// ==========================================================

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepositoryImpl(
    remote: ref.watch(connectionRemoteDataSourceProvider),
    simulated: ref.watch(simulatedDeviceDataSourceProvider),
  );
});

// ==========================================================
// USE CASES
// ==========================================================

final getDevicesProvider = Provider<GetDevices>((ref) {
  return GetDevices(ref.watch(connectionRepositoryProvider));
});

final connectDeviceProvider = Provider<ConnectDevice>((ref) {
  return ConnectDevice(ref.watch(connectionRepositoryProvider));
});

final disconnectDeviceProvider = Provider<DisconnectDevice>((ref) {
  return DisconnectDevice(ref.watch(connectionRepositoryProvider));
});

// ==========================================================
// ESTADO DA CONEXÃO
// ==========================================================

enum DeviceConnectionStatus {
  disconnected,
  searching,
  connecting,
  connected,
  error,
}

class DeviceConnectionState {
  final DeviceConnectionStatus status;

  // Dispositivos encontrados na última busca.
  final List<Device> devices;

  // Dispositivo pareado.
  final Device? device;

  // Mensagem de erro/aviso.
  final String? message;

  // Usuário escolheu continuar sem dispositivo.
  final bool skipped;

  // Já foi feita ao menos uma busca.
  final bool searched;

  // Diagnóstico enviado pelo dispositivo.
  final int? rssi;
  final double? noiseFloorDb;

  const DeviceConnectionState({
    this.status = DeviceConnectionStatus.disconnected,
    this.devices = const [],
    this.device,
    this.message,
    this.skipped = false,
    this.searched = false,
    this.rssi,
    this.noiseFloorDb,
  });

  bool get isConnected =>
      status == DeviceConnectionStatus.connected && device != null;

  bool get isSimulated => device?.isSimulated ?? false;

  DeviceConnectionState copyWith({
    DeviceConnectionStatus? status,
    List<Device>? devices,
    Device? device,
    bool clearDevice = false,
    String? message,
    bool clearMessage = false,
    bool? skipped,
    bool? searched,
    int? rssi,
    double? noiseFloorDb,
  }) {
    return DeviceConnectionState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      device: clearDevice ? null : (device ?? this.device),
      message: clearMessage ? null : (message ?? this.message),
      skipped: skipped ?? this.skipped,
      searched: searched ?? this.searched,
      rssi: rssi ?? this.rssi,
      noiseFloorDb: noiseFloorDb ?? this.noiseFloorDb,
    );
  }
}

class ConnectionNotifier extends Notifier<DeviceConnectionState> {
  StreamSubscription<DeviceEvent>? _subscription;

  @override
  DeviceConnectionState build() {
    final repository = ref.watch(connectionRepositoryProvider);

    _subscription?.cancel();
    _subscription = repository.events.listen(_onEvent);
    ref.onDispose(() => _subscription?.cancel());

    return const DeviceConnectionState();
  }

  void _onEvent(DeviceEvent event) {
    if (event is ConnectionLostEvent) {
      state = state.copyWith(
        status: DeviceConnectionStatus.disconnected,
        clearDevice: true,
        message: 'A conexão com o dispositivo foi perdida.',
      );
    } else if (event is DeviceStatusEvent) {
      state = state.copyWith(
        rssi: event.rssi,
        noiseFloorDb: event.noiseFloorDb,
      );
    }
  }

  bool get isNetworkSupported =>
      ref.read(connectionRepositoryProvider).isNetworkSupported;

  // Busca dispositivos na rede (ou em um IP informado manualmente).
  Future<void> search({String? address}) async {
    if (!isNetworkSupported) {
      state = state.copyWith(
        status: DeviceConnectionStatus.error,
        searched: true,
        message: 'A conexão com o dispositivo não está disponível no navegador. '
            'Use o modo demonstração ou o app no celular/computador.',
      );
      return;
    }

    state = state.copyWith(
      status: DeviceConnectionStatus.searching,
      clearMessage: true,
    );

    try {
      final devices = await ref.read(getDevicesProvider)(address: address);
      state = state.copyWith(
        status: state.device != null
            ? DeviceConnectionStatus.connected
            : DeviceConnectionStatus.disconnected,
        devices: devices,
        searched: true,
        message: devices.isEmpty
            ? 'Nenhum dispositivo encontrado. Verifique se ele está ligado '
                'e conectado à mesma rede Wi-Fi.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(
        status: DeviceConnectionStatus.error,
        searched: true,
        message: _clean(e),
      );
    }
  }

  // Pareia com o dispositivo escolhido.
  Future<bool> connect(Device device) async {
    state = state.copyWith(
      status: DeviceConnectionStatus.connecting,
      clearMessage: true,
    );

    try {
      await ref.read(connectDeviceProvider)(device);
      state = state.copyWith(
        status: DeviceConnectionStatus.connected,
        device: device,
        skipped: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: DeviceConnectionStatus.error,
        clearDevice: true,
        message: _clean(e),
      );
      return false;
    }
  }

  // Conecta ao dispositivo virtual (modo demonstração).
  Future<bool> useSimulator() {
    return connect(ref.read(connectionRepositoryProvider).simulatedDevice);
  }

  // Desconexão segura (RU17).
  Future<void> disconnect() async {
    await ref.read(disconnectDeviceProvider)();
    state = state.copyWith(
      status: DeviceConnectionStatus.disconnected,
      clearDevice: true,
      clearMessage: true,
    );
  }

  // Continua sem dispositivo (apenas navegação pelo repertório).
  void skip() {
    state = state.copyWith(skipped: true);
  }

  // Volta para a tela de conexão.
  void showConnectionScreen() {
    state = state.copyWith(skipped: false);
  }

  String _clean(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, DeviceConnectionState>(
  ConnectionNotifier.new,
);

import '../../domain/entities/device.dart';
import '../protocol/device_protocol.dart';

class DeviceModel {
  final String id;
  final String name;
  final String address;
  final int port;
  final String firmware;
  final int rssi;
  final int state;
  final bool isSimulated;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.firmware,
    required this.rssi,
    required this.state,
    this.isSimulated = false,
  });

  // Cria o model a partir do pacote ANNOUNCE e do endereço de origem.
  factory DeviceModel.fromAnnounce(
    AnnouncePacket packet, {
    required String address,
    required int port,
  }) {
    return DeviceModel(
      id: packet.mac,
      name: packet.name.isEmpty ? 'Dispositivo ${packet.mac}' : packet.name,
      address: address,
      port: port,
      firmware: packet.firmware,
      rssi: packet.rssi,
      state: packet.state,
    );
  }

  Device toEntity() {
    return Device(
      id: id,
      name: name,
      address: address,
      port: port,
      firmware: firmware,
      rssi: rssi,
      busy: state != DeviceProtocol.stateIdle,
      isSimulated: isSimulated,
    );
  }
}

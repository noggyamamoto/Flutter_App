import '../entities/device.dart';
import '../repositories/connection_repository.dart';

class ConnectDevice {
  final ConnectionRepository repository;

  ConnectDevice(this.repository);

  Future<void> call(Device device) {
    return repository.connect(device);
  }
}

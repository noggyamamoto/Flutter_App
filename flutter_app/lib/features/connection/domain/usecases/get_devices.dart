import '../entities/device.dart';
import '../repositories/connection_repository.dart';

class GetDevices {
  final ConnectionRepository repository;

  GetDevices(this.repository);

  // Busca por broadcast ou, se informado, diretamente em um IP.
  Future<List<Device>> call({
    Duration timeout = const Duration(seconds: 3),
    String? address,
  }) {
    return repository.getDevices(timeout: timeout, address: address);
  }
}

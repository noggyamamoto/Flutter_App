// Contrato do Repository.
import '../repositories/auth_repository.dart';

// Caso de uso responsável pelo logout.
class Logout {
  // Repository utilizado.
  final AuthRepository repository;

  // Construtor.
  Logout(this.repository);

  // Executa o logout.
  Future<void> call() {
    // Solicita o logout ao Repository.
    return repository.logout();
  }
}

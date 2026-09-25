// Entidade do usuário.
import '../entities/app_user.dart';

// Contrato do Repository.
import '../repositories/auth_repository.dart';

// Caso de uso responsável pelo login.
class Login {
  // Repository que executará a operação.
  final AuthRepository repository;

  // Construtor.
  Login(this.repository);

  // Executa o caso de uso.
  Future<AppUser> call({
    required String email,
    required String senha,
  }) {
    // Solicita o login ao Repository.
    return repository.login(
      email: email,
      senha: senha,
    );
  }
}

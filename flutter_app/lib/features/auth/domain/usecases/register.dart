// Entidade do usuário.
import '../entities/app_user.dart';

// Contrato do Repository.
import '../repositories/auth_repository.dart';

// Caso de uso responsável pelo cadastro.
class Register {
  // Repository utilizado pelo caso de uso.
  final AuthRepository repository;

  // Construtor.
  Register(this.repository);

  // Executa o cadastro.
  Future<AppUser> call({
    required String nome,
    required String email,
    required String senha,
  }) {
    // Encaminha a operação para o Repository.
    return repository.register(
      nome: nome,
      email: email,
      senha: senha,
    );
  }
}

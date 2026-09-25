// Entidade do usuário.
import '../entities/app_user.dart';

// Define o contrato do repositório de autenticação.
//
// A camada de domínio conhece apenas esse contrato.
// Ela não precisa saber que estamos utilizando Firebase.
abstract class AuthRepository {
  // Realiza cadastro.
  Future<AppUser> register({
    required String nome,
    required String email,
    required String senha,
  });

  // Realiza login.
  Future<AppUser> login({
    required String email,
    required String senha,
  });

  // Retorna o usuário atualmente autenticado.
  AppUser? getCurrentUser();

  // Encerra a sessão.
  Future<void> logout();
}

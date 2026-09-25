import '../../domain/entities/app_user.dart';

// Define as operações que a camada de dados
// disponibiliza para autenticação.
abstract class AuthRemoteDataSource {
  // Cria uma nova conta.
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

  // Recupera o usuário atualmente autenticado.
  AppUser? getCurrentUser();

  // Encerra a sessão atual.
  Future<void> logout();
}

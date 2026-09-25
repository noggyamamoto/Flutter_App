// Entidade do usuário.
import '../../domain/entities/app_user.dart';

// Contrato do Repository.
import '../../domain/repositories/auth_repository.dart';

// Contrato do DataSource.
import '../datasources/auth_remote_datasource.dart';

// Implementação do Repository.
class AuthRepositoryImpl implements AuthRepository {
  // DataSource responsável pelo acesso aos serviços externos.
  final AuthRemoteDataSource dataSource;

  // Construtor.
  AuthRepositoryImpl(this.dataSource);

  // ==========================================================
  // CADASTRO
  // ==========================================================

  @override
  Future<AppUser> register({
    required String nome,
    required String email,
    required String senha,
  }) {
    // Encaminha a operação para o DataSource.
    return dataSource.register(
      nome: nome,
      email: email,
      senha: senha,
    );
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  @override
  Future<AppUser> login({
    required String email,
    required String senha,
  }) {
    // Encaminha a operação para o DataSource.
    return dataSource.login(
      email: email,
      senha: senha,
    );
  }

  // ==========================================================
  // USUÁRIO ATUAL
  // ==========================================================

  @override
  AppUser? getCurrentUser() {
    // Solicita o usuário atual ao DataSource.
    return dataSource.getCurrentUser();
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  @override
  Future<void> logout() {
    // Solicita o logout ao DataSource.
    return dataSource.logout();
  }
}

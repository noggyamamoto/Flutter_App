// Firebase Authentication.
import 'package:firebase_auth/firebase_auth.dart';

// Cloud Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';

// Riverpod.
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Entidade do usuário.
import '../../domain/entities/app_user.dart';

// DataSource.
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/auth_remote_datasource_impl.dart';

// Repository.
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

// UseCases.
import '../../domain/usecases/login.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/logout.dart';


// ==========================================================
// FIREBASE AUTH PROVIDER
// ==========================================================

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  // Retorna a instância do Firebase Authentication.
  return FirebaseAuth.instance;
});


// ==========================================================
// FIRESTORE PROVIDER
// ==========================================================

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  // Retorna a instância do Cloud Firestore.
  return FirebaseFirestore.instance;
});


// ==========================================================
// DATASOURCE PROVIDER
// ==========================================================

final authDataSourceProvider =
    Provider<AuthRemoteDataSource>((ref) {
  // Recupera a instância do Firebase Authentication.
  final auth = ref.watch(firebaseAuthProvider);

  // Recupera a instância do Firestore.
  final firestore = ref.watch(firestoreProvider);

  // Cria a implementação do DataSource.
  return AuthRemoteDataSourceImpl(
    auth: auth,
    firestore: firestore,
  );
});


// ==========================================================
// REPOSITORY PROVIDER
// ==========================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Recupera o DataSource.
  final dataSource = ref.watch(authDataSourceProvider);

  // Cria o Repository.
  return AuthRepositoryImpl(dataSource);
});


// ==========================================================
// USE CASE: LOGIN
// ==========================================================

final loginProvider = Provider<Login>((ref) {
  // Recupera o Repository.
  final repository = ref.watch(authRepositoryProvider);

  // Cria o UseCase.
  return Login(repository);
});


// ==========================================================
// USE CASE: CADASTRO
// ==========================================================

final registerProvider = Provider<Register>((ref) {
  // Recupera o Repository.
  final repository = ref.watch(authRepositoryProvider);

  // Cria o UseCase.
  return Register(repository);
});


// ==========================================================
// USE CASE: LOGOUT
// ==========================================================

final logoutProvider = Provider<Logout>((ref) {
  // Recupera o Repository.
  final repository = ref.watch(authRepositoryProvider);

  // Cria o UseCase.
  return Logout(repository);
});


// ==========================================================
// STATUS DA AUTENTICAÇÃO
// ==========================================================

enum AuthStatus {
  // Estado inicial.
  initial,

  // Alguma operação está acontecendo.
  loading,

  // Usuário autenticado.
  authenticated,

  // Usuário não autenticado.
  unauthenticated,

  // Ocorreu algum erro.
  error,
}


// ==========================================================
// ESTADO DA AUTENTICAÇÃO
// ==========================================================

class AuthState {
  // Status atual.
  final AuthStatus status;

  // Usuário autenticado.
  final AppUser? user;

  // Mensagem de erro.
  final String? errorMessage;

  // Construtor.
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  // Cria uma cópia do estado atual.
  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      // Aqui o errorMessage NÃO usa "?? this.errorMessage"
      // de propósito: passar null explicitamente limpa o erro.
      errorMessage: errorMessage,
    );
  }
}


// ==========================================================
// AUTH NOTIFIER
// ==========================================================

class AuthNotifier extends Notifier<AuthState> {

  // ========================================================
  // ESTADO INICIAL
  // ========================================================

  @override
  AuthState build() {
    // Verifica se existe um usuário autenticado.
    final firebaseUser =
        ref.read(firebaseAuthProvider).currentUser;

    // Se existir usuário, considera autenticado.
    if (firebaseUser != null) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(
          id: firebaseUser.uid,
          nome: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
        ),
      );
    }

    // Caso contrário, o usuário está deslogado.
    return const AuthState(
      status: AuthStatus.unauthenticated,
    );
  }

  // ========================================================
  // LIMPAR ERRO
  // ========================================================

  /// Limpa a mensagem de erro atual.
  ///
  /// Deve ser chamado pelas telas depois de exibir o
  /// SnackBar com o erro, evitando que a mesma mensagem
  /// apareça novamente em rebuilds seguintes.
  void clearError() {
    // Só faz sentido limpar se houver erro.
    if (state.errorMessage == null) return;

    // Volta o estado para "não autenticado" sem erro.
    state = AuthState(
      status: AuthStatus.unauthenticated,
      user: state.user,
    );
  }

  // ========================================================
  // LOGIN
  // ========================================================

  Future<void> login({
    required String email,
    required String senha,
  }) async {
    // Informa à interface que o login começou.
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      // Recupera o caso de uso.
      final loginUseCase = ref.read(loginProvider);

      // Executa o login.
      final user = await loginUseCase(
        email: email,
        senha: senha,
      );

      // Atualiza o estado para autenticado.
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } on FirebaseAuthException catch (error) {
      // Trata erros conhecidos do Firebase.
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getAuthErrorMessage(error.code),
      );
    } catch (error) {
      // Trata erros inesperados.
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erro ao realizar login.',
      );
    }
  }

  // ========================================================
  // CADASTRO
  // ========================================================

  Future<void> register({
    required String nome,
    required String email,
    required String senha,
  }) async {
    // Informa que o cadastro começou.
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      // Recupera o caso de uso.
      final registerUseCase = ref.read(registerProvider);

      // Executa o cadastro.
      final user = await registerUseCase(
        nome: nome,
        email: email,
        senha: senha,
      );

      // Após o cadastro, o Firebase já autentica
      // o usuário automaticamente.
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } on FirebaseAuthException catch (error) {
      // Trata erros do Firebase.
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getAuthErrorMessage(error.code),
      );
    } catch (error) {
      // Trata erros inesperados.
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erro ao realizar cadastro.',
      );
    }
  }

  // ========================================================
  // LOGOUT
  // ========================================================

  Future<void> logout() async {
    // Informa à interface que o logout começou.
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      // Recupera o caso de uso.
      final logoutUseCase = ref.read(logoutProvider);

      // Executa o logout.
      await logoutUseCase();

      // Atualiza o estado.
      state = const AuthState(
        status: AuthStatus.unauthenticated,
      );
    } on FirebaseAuthException catch (error) {
      // Trata erros do Firebase durante o logout.
      state = AuthState(
        status: AuthStatus.error,
        user: state.user,
        errorMessage: _getAuthErrorMessage(error.code),
      );
    } catch (error) {
      // Trata erros inesperados.
      state = AuthState(
        status: AuthStatus.error,
        user: state.user,
        errorMessage: 'Erro ao encerrar sessão.',
      );
    }
  }

  // ========================================================
  // TRATAMENTO DOS ERROS
  // ========================================================

  String _getAuthErrorMessage(String code) {
    switch (code) {
      // E-mail já cadastrado.
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';

      // E-mail inválido.
      case 'invalid-email':
        return 'Digite um e-mail válido.';

      // Senha fraca.
      case 'weak-password':
        return 'A senha é muito fraca.';

      // Usuário não encontrado.
      case 'user-not-found':
        return 'Usuário não encontrado.';

      // Credenciais inválidas.
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';

      // Conta desativada.
      case 'user-disabled':
        return 'Esta conta foi desativada.';

      // Muitas tentativas.
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';

      // Falha de rede.
      case 'network-request-failed':
        return 'Falha de conexão. Verifique sua internet.';

      // Operação não permitida.
      case 'operation-not-allowed':
        return 'Este método de login não está habilitado.';

      // Login recente obrigatório.
      case 'requires-recent-login':
        return 'Faça login novamente para continuar.';

      // Erro genérico.
      default:
        return 'Não foi possível realizar a autenticação.';
    }
  }
}


// ==========================================================
// PROVIDER PRINCIPAL
// ==========================================================

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
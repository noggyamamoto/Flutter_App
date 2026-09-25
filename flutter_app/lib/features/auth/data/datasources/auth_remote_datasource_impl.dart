// Firebase Authentication.
import 'package:firebase_auth/firebase_auth.dart';

// Cloud Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';

// Entidade do usuário.
import '../../domain/entities/app_user.dart';

// Contrato do DataSource.
import 'auth_remote_datasource.dart';

// Implementação concreta do DataSource.
class AuthRemoteDataSourceImpl
    implements AuthRemoteDataSource {
  // Instância do Firebase Authentication.
  final FirebaseAuth auth;

  // Instância do Cloud Firestore.
  final FirebaseFirestore firestore;

  // Construtor.
  //
  // Recebemos as dependências por parâmetro
  // para facilitar testes e manter a separação
  // de responsabilidades.
  AuthRemoteDataSourceImpl({
    required this.auth,
    required this.firestore,
  });

  // ==========================================================
  // CADASTRO
  // ==========================================================

  @override
  Future<AppUser> register({
    required String nome,
    required String email,
    required String senha,
  }) async {
    // Solicita ao Firebase Authentication
    // a criação de uma conta com e-mail e senha.
    final credential =
        await auth.createUserWithEmailAndPassword(
      // E-mail informado pelo usuário.
      email: email.trim(),

      // Senha informada pelo usuário.
      password: senha,
    );

    // Recupera o usuário criado.
    final firebaseUser = credential.user;

    // Verifica se o Firebase retornou um usuário.
    if (firebaseUser == null) {
      throw Exception(
        'Não foi possível criar o usuário.',
      );
    }

    // Atualiza o nome de exibição do usuário
    // no Firebase Authentication.
    await firebaseUser.updateDisplayName(
      nome.trim(),
    );

    // Cria o documento correspondente no Firestore.
    //
    // O UID do Authentication será utilizado
    // como ID do documento.
    await firestore
        .collection('usuarios')
        .doc(firebaseUser.uid)
        .set({
      // UID gerado pelo Firebase.
      'id': firebaseUser.uid,

      // Nome do usuário.
      'nome': nome.trim(),

      // E-mail utilizado no cadastro.
      'email': email.trim(),

      // Data de criação.
      'dataCriacao': FieldValue.serverTimestamp(),
    });

    // Retorna a entidade do usuário.
    return AppUser(
      // UID gerado pelo Firebase.
      id: firebaseUser.uid,

      // Nome informado no cadastro.
      nome: nome.trim(),

      // E-mail informado.
      email: email.trim(),
    );
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  @override
  Future<AppUser> login({
    required String email,
    required String senha,
  }) async {
    // Solicita ao Firebase Authentication
    // a autenticação utilizando e-mail e senha.
    final credential =
        await auth.signInWithEmailAndPassword(
      // E-mail informado.
      email: email.trim(),

      // Senha informada.
      password: senha,
    );

    // Recupera o usuário autenticado.
    final firebaseUser = credential.user;

    // Verifica se o usuário foi encontrado.
    if (firebaseUser == null) {
      throw Exception(
        'Não foi possível realizar o login.',
      );
    }

    // Busca os dados adicionais do usuário no Firestore.
    final document = await firestore
        .collection('usuarios')
        .doc(firebaseUser.uid)
        .get();

    // Recupera os dados do documento.
    final data = document.data();

    // Caso o documento não exista,
    // utiliza os dados disponíveis no Authentication.
    if (data == null) {
      return AppUser(
        id: firebaseUser.uid,
        nome: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? email.trim(),
      );
    }

    // Retorna o usuário utilizando
    // os dados armazenados no Firestore.
    return AppUser(
      // UID.
      id: firebaseUser.uid,

      // Nome armazenado.
      nome: data['nome'] as String? ??
          firebaseUser.displayName ??
          '',

      // E-mail armazenado.
      email: data['email'] as String? ??
          firebaseUser.email ??
          email.trim(),
    );
  }

  // ==========================================================
  // USUÁRIO ATUAL
  // ==========================================================

  @override
  AppUser? getCurrentUser() {
    // Recupera o usuário que está autenticado
    // neste momento.
    final firebaseUser = auth.currentUser;

    // Caso não exista usuário autenticado,
    // retorna null.
    if (firebaseUser == null) {
      return null;
    }

    // Converte o usuário do Firebase
    // em uma entidade do domínio.
    return AppUser(
      // UID.
      id: firebaseUser.uid,

      // Nome.
      nome: firebaseUser.displayName ?? '',

      // E-mail.
      email: firebaseUser.email ?? '',
    );
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  @override
  Future<void> logout() async {
    // Encerra a sessão atual.
    await auth.signOut();
  }
}

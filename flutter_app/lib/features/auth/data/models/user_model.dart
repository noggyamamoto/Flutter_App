import '../../domain/entities/app_user.dart';

// Model utilizado pela camada de dados.
class UserModel {
  // ID do usuário.
  final String id;

  // Nome do usuário.
  final String nome;

  // E-mail do usuário.
  final String email;

  // Construtor.
  const UserModel({
    // ID obrigatório.
    required this.id,

    // Nome obrigatório.
    required this.nome,

    // E-mail obrigatório.
    required this.email,
  });

  // Cria um UserModel a partir de um Map.
  //
  // Será utilizado para transformar os dados
  // recebidos do Firestore em um objeto Dart.
  factory UserModel.fromMap(
    Map<String, dynamic> map,
  ) {
    // Retorna o Model preenchido.
    return UserModel(
      // Recupera o ID.
      id: map['id'] as String? ?? '',

      // Recupera o nome.
      nome: map['nome'] as String? ?? '',

      // Recupera o e-mail.
      email: map['email'] as String? ?? '',
    );
  }

  // Converte o Model para Map.
  //
  // Será utilizado quando precisarmos salvar
  // os dados no Firestore.
  Map<String, dynamic> toMap() {
    // Retorna os campos.
    return {
      'id': id,
      'nome': nome,
      'email': email,
    };
  }

  // Converte o Model para a entidade do domínio.
  AppUser toEntity() {
    // Retorna uma entidade AppUser.
    return AppUser(
      id: id,
      nome: nome,
      email: email,
    );
  }
}

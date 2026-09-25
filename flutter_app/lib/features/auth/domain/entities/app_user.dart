// Essa classe pertence ao domínio, por isso não depende
// diretamente do Firebase.
class AppUser {
  // Identificador único do usuário.
  //
  // Será o UID gerado pelo Firebase Authentication.
  final String id;

  // Nome informado no cadastro.
  final String nome;

  // E-mail utilizado na autenticação.
  final String email;

  // Construtor da entidade.
  const AppUser({
    // ID obrigatório.
    required this.id,

    // Nome obrigatório.
    required this.nome,

    // E-mail obrigatório.
    required this.email,
  });
}

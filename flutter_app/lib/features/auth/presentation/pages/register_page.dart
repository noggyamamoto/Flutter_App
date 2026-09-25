import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({
    super.key,
  });

  @override
  ConsumerState<RegisterPage> createState() {
    return _RegisterPageState();
  }
}

class _RegisterPageState
    extends ConsumerState<RegisterPage> {
  // Controla o campo de nome.
  final nomeController = TextEditingController();

  // Controla o campo de e-mail.
  final emailController = TextEditingController();

  // Controla o campo de senha.
  final senhaController = TextEditingController();

  // Controla a confirmação da senha.
  final confirmarSenhaController =
      TextEditingController();

  // Controla a visibilidade da senha.
  bool senhaVisivel = false;

  // Controla a visibilidade da confirmação.
  bool confirmarSenhaVisivel = false;

  @override
  void dispose() {
    // Libera o controlador do nome.
    nomeController.dispose();

    // Libera o controlador do e-mail.
    emailController.dispose();

    // Libera o controlador da senha.
    senhaController.dispose();

    // Libera o controlador da confirmação.
    confirmarSenhaController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    // Recupera o nome.
    final nome = nomeController.text.trim();

    // Recupera o e-mail.
    final email = emailController.text.trim();

    // Recupera a senha.
    final senha = senhaController.text;

    // Recupera a confirmação.
    final confirmarSenha =
        confirmarSenhaController.text;

    // Validação do nome.
    if (nome.isEmpty) {
      _showMessage(
        'Digite seu nome.',
      );

      return;
    }

    // Validação do e-mail.
    if (email.isEmpty) {
      _showMessage(
        'Digite seu e-mail.',
      );

      return;
    }

    // Validação da senha.
    if (senha.isEmpty) {
      _showMessage(
        'Digite uma senha.',
      );

      return;
    }

    // Confirmação da senha.
    if (senha != confirmarSenha) {
      _showMessage(
        'As senhas não coincidem.',
      );

      return;
    }

    // Solicita o cadastro ao AuthNotifier.
    await ref
        .read(authProvider.notifier)
        .register(
          nome: nome,
          email: email,
          senha: senha,
        );
  }

  void _showMessage(String message) {
    // Exibe uma mensagem na tela.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Observa o estado da autenticação.
    final authState = ref.watch(authProvider);

    // Observa mudanças no estado para mostrar erros.
    ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        // Se ocorrer erro, mostra a mensagem.
        if (next.status == AuthStatus.error &&
            next.errorMessage != null) {
          _showMessage(
            next.errorMessage!,
          );
        }
      },
    );

    // Verifica se o cadastro está sendo processado.
    final isLoading =
        authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0F0E17),

        foregroundColor: Colors.white,

        elevation: 0,

        title: const Text(
          'Criar conta',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,

                children: [
                  // Título.
                  const Text(
                    'Crie sua conta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtítulo.
                  const Text(
                    'Cadastre-se para acompanhar seu desempenho.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Nome.
                  _buildTextField(
                    controller: nomeController,
                    label: 'Nome',
                    icon: Icons.person_outline,
                  ),

                  const SizedBox(height: 16),

                  // E-mail.
                  _buildTextField(
                    controller: emailController,
                    label: 'E-mail',
                    icon: Icons.email_outlined,
                    keyboardType:
                        TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  // Senha.
                  _buildTextField(
                    controller: senhaController,
                    label: 'Senha',
                    icon: Icons.lock_outline,
                    obscureText: !senhaVisivel,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          senhaVisivel =
                              !senhaVisivel;
                        });
                      },
                      icon: Icon(
                        senhaVisivel
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Confirmação da senha.
                  _buildTextField(
                    controller:
                        confirmarSenhaController,
                    label: 'Confirmar senha',
                    icon: Icons.lock_outline,
                    obscureText:
                        !confirmarSenhaVisivel,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          confirmarSenhaVisivel =
                              !confirmarSenhaVisivel;
                        });
                      },
                      icon: Icon(
                        confirmarSenhaVisivel
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão de cadastro.
                  SizedBox(
                    height: 52,

                    child: ElevatedButton(
                      onPressed:
                          isLoading ? null : _register,

                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),

                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Criar conta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Voltar para login.
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pop(
                              context,
                            );
                          },
                    child: const Text(
                      'Já tenho uma conta',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    // Campo de texto reutilizável.
    return TextField(
      // Controlador do campo.
      controller: controller,

      // Tipo de teclado.
      keyboardType: keyboardType,

      // Oculta o conteúdo quando necessário.
      obscureText: obscureText,

      // Cor do texto.
      style: const TextStyle(
        color: Colors.white,
      ),

      // Decoração.
      decoration: InputDecoration(
        // Texto do campo.
        labelText: label,

        // Cor do label.
        labelStyle: const TextStyle(
          color: Colors.white70,
        ),

        // Ícone inicial.
        prefixIcon: Icon(
          icon,
          color: Colors.white70,
        ),

        // Ícone final opcional.
        suffixIcon: suffixIcon,

        // Fundo.
        filled: true,

        fillColor:
            Colors.white.withValues(alpha: 0.08),

        // Bordas.
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

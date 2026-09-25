import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  ConsumerState<LoginPage> createState() {
    return _LoginPageState();
  }
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // Controla o campo de e-mail.
  final emailController = TextEditingController();

  // Controla o campo de senha.
  final senhaController = TextEditingController();

  // Controla a visibilidade da senha.
  bool senhaVisivel = false;

  @override
  void dispose() {
    // Libera o controlador do e-mail.
    emailController.dispose();

    // Libera o controlador da senha.
    senhaController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    // Remove espaços desnecessários.
    final email = emailController.text.trim();

    // Recupera a senha.
    final senha = senhaController.text;

    // Validação básica.
    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha e-mail e senha.',
          ),
        ),
      );

      return;
    }

    // Solicita o login ao AuthNotifier.
    await ref.read(authProvider.notifier).login(
          email: email,
          senha: senha,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Observa o estado da autenticação.
    final authState = ref.watch(authProvider);

    // Mostra erro quando houver.
    ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (next.status == AuthStatus.error &&
            next.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                next.errorMessage!,
              ),
            ),
          );
        }
      },
    );

    // Verifica se está carregando.
    final isLoading =
        authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

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
                    'Entrar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtítulo.
                  const Text(
                    'Entre para continuar seus estudos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Campo de e-mail.
                  TextField(
                    controller: emailController,

                    keyboardType:
                        TextInputType.emailAddress,

                    style: const TextStyle(
                      color: Colors.white,
                    ),

                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor:
                          Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Campo de senha.
                  TextField(
                    controller: senhaController,

                    obscureText: !senhaVisivel,

                    style: const TextStyle(
                      color: Colors.white,
                    ),

                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white70,
                      ),
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
                      filled: true,
                      fillColor:
                          Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão de login.
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          isLoading ? null : _login,

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
                              'Entrar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Link para cadastro.
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      const Text(
                        'Ainda não possui uma conta?',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RegisterPage(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Cadastre-se',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../songs/presentation/pages/songs_page.dart';

import '../providers/auth_provider.dart';

import 'login_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa o estado da autenticação.
    final authState = ref.watch(authProvider);

    // Verifica o estado atual.
    switch (authState.status) {
      // ------------------------------------------------------
      // ESTADO INICIAL
      // ------------------------------------------------------

      case AuthStatus.initial:

        // Mostra uma tela de carregamento.
        return const Scaffold(
          backgroundColor: Color(0xFF0F0E17),

          body: Center(
            child: CircularProgressIndicator(
              color: Colors.deepPurple,
            ),
          ),
        );

      // ------------------------------------------------------
      // CARREGANDO
      // ------------------------------------------------------

      case AuthStatus.loading:

        // Mostra carregamento.
        return const Scaffold(
          backgroundColor: Color(0xFF0F0E17),

          body: Center(
            child: CircularProgressIndicator(
              color: Colors.deepPurple,
            ),
          ),
        );

      // ------------------------------------------------------
      // AUTENTICADO
      // ------------------------------------------------------

      case AuthStatus.authenticated:

        // Usuário autenticado pode acessar o aplicativo.
        return const SongsPage();

      // ------------------------------------------------------
      // NÃO AUTENTICADO
      // ------------------------------------------------------

      case AuthStatus.unauthenticated:

        // Usuário precisa realizar login.
        return const LoginPage();

      // ------------------------------------------------------
      // ERRO
      // ------------------------------------------------------

      case AuthStatus.error:

        // Em caso de erro, volta para a tela de login.
        return const LoginPage();
    }
  }
}

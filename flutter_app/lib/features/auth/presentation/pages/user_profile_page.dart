import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

// Página que exibe as informações do usuário autenticado
// e permite encerrar a sessão.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa o estado de autenticação.
    final authState = ref.watch(authProvider);

    // Recupera o usuário atual.
    final user = authState.user;

    // Indica se há uma operação em andamento.
    final isLoading = authState.status == AuthStatus.loading;

    // Exibe erros provenientes do logout.
    ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (next.status == AuthStatus.error &&
            next.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: Colors.redAccent,
            ),
          );

          // Limpa o erro para não exibir novamente.
          ref.read(authProvider.notifier).clearError();
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Meu perfil'),
      ),

      body: user == null
          // Caso não haja usuário, mostra mensagem.
          ? const Center(
              child: Text(
                'Nenhum usuário autenticado.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 480),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,

                      children: [
                        // Avatar com iniciais do nome.
                        Center(
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.deepPurple,
                            child: Text(
                              _iniciais(user.nome),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Nome em destaque.
                        Text(
                          user.nome.isEmpty
                              ? 'Usuário'
                              : user.nome,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // E-mail em destaque secundário.
                        Text(
                          user.email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Informação: nome.
                        _InfoTile(
                          icon: Icons.person_outline,
                          label: 'Nome',
                          value: user.nome.isEmpty
                              ? '—'
                              : user.nome,
                        ),

                        const SizedBox(height: 12),

                        // Informação: e-mail.
                        _InfoTile(
                          icon: Icons.email_outlined,
                          label: 'E-mail',
                          value: user.email.isEmpty
                              ? '—'
                              : user.email,
                        ),

                        const SizedBox(height: 12),

                        // Informação: ID (UID do Firebase).
                        _InfoTile(
                          icon: Icons.badge_outlined,
                          label: 'ID',
                          value: user.id,
                        ),

                        const SizedBox(height: 32),

                        // Botão de logout.
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: isLoading
                                ? null
                                : () => _confirmLogout(context, ref),

                            icon: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.logout),

                            label: Text(
                              isLoading
                                  ? 'Saindo...'
                                  : 'Sair da conta',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
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

  // Retorna as iniciais do nome para exibir no avatar.
  String _iniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return '?';

    if (partes.length == 1) {
      return partes.first[0].toUpperCase();
    }

    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  // Exibe um diálogo de confirmação antes de sair.
  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: const Text(
            'Sair da conta?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Você precisará fazer login novamente para acessar o app.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text(
                'Sair',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

// Widget interno que exibe ícone, rótulo e valor.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
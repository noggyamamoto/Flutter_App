import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/presentation/pages/auth_gate.dart';
import 'features/configuration/presentation/providers/configuration_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A primeira tela aparece na hora; o Firebase é iniciado em paralelo
  // (antes, a tela ficava em branco até ele terminar).
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Inicialização do Firebase (uma vez por execução do app). Sem novas
// tentativas automáticas: em caso de falha a abertura mostra o aviso e o
// botão "Tentar novamente".
final firebaseInitProvider = FutureProvider<FirebaseApp>(
  (ref) => Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ),
  retry: (_, _) => null,
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Partitura IoT',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _Startup(),
    );
  }
}

// Abertura: inicia o Firebase e, enquanto isso, carrega as preferências
// (metrônomo, zoom...) para a primeira execução já usar as do usuário.
class _Startup extends ConsumerWidget {
  const _Startup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(configurationProvider);
    final firebase = ref.watch(firebaseInitProvider);

    return firebase.when(
      data: (_) => const AuthGate(),
      loading: () => const _Splash(),
      error: (error, _) => _Splash(
        message: 'Não foi possível iniciar o aplicativo. Verifique a conexão com a internet.',
        onRetry: () => ref.invalidate(firebaseInitProvider),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const _Splash({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Partitura IoT',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (message == null)
                const CircularProgressIndicator(color: Colors.deepPurple)
              else ...[
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

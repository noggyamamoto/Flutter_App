import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../songs/presentation/pages/songs_page.dart';
import '../providers/connection_provider.dart';
import 'connection_page.dart';

// Após o login, mostra a tela de conexão até que o usuário pareie um
// dispositivo (ou escolha seguir sem ele) e então abre o repertório.
class DeviceGate extends ConsumerWidget {
  const DeviceGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionProvider);

    if (state.skipped) {
      return const SongsPage();
    }

    return const ConnectionPage();
  }
}

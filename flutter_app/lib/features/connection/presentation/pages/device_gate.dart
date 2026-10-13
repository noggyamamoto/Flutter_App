import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../songs/presentation/pages/songs_page.dart';
import '../../../songs/presentation/providers/songs_provider.dart';
import '../providers/connection_provider.dart';
import 'connection_page.dart';

// Após o login, mostra a tela de conexão até que o usuário pareie um
// dispositivo (ou escolha seguir sem ele) e então abre o repertório.
class DeviceGate extends ConsumerWidget {
  const DeviceGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped = ref.watch(connectionProvider.select((c) => c.skipped));

    // Repertório e músicas recentes carregados enquanto o usuário conecta o
    // dispositivo: o repertório abre já preenchido.
    ref.listen(songsProvider, (_, _) {});
    final userId = ref.watch(authProvider.select((a) => a.user?.id));
    if (userId != null) ref.listen(recentSongIdsProvider(userId), (_, _) {});

    if (skipped) {
      return const SongsPage();
    }

    return const ConnectionPage();
  }
}

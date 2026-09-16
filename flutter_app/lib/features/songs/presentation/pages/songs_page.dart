import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/features/songs/presentation/providers/songs_provider.dart';

class SongsPage extends ConsumerWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partituras'),
      ),
      body: songsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Text('Erro: $error'),
        ),
        data: (songs) {
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];

              return ListTile(
                title: Text(song.titulo),
                subtitle: Text(song.compositor),
              );
            },
          );
        },
      ),
    );
  }
}
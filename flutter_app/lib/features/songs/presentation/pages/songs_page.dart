import 'package:flutter/material.dart';
import 'package:flutter_app/features/performance/presentation/pages/performance_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_app/features/songs/presentation/providers/songs_provider.dart';

class SongsPage extends ConsumerWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: songsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => Center(
            child: Text(
              'Erro: $error',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          data: (songs) {
            return _SongsContent(songs: songs);
          },
        ),
      ),
    );
  }
}

class _SongsContent extends StatelessWidget {
  final List<Song> songs;

  const _SongsContent({
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    final faceis = songs
        .where((song) => song.nivelDificuldade.toLowerCase() == 'fácil')
        .toList();

    final medios = songs
        .where((song) => song.nivelDificuldade.toLowerCase() == 'médio')
        .toList();

    final dificeis = songs
        .where((song) => song.nivelDificuldade.toLowerCase() == 'difícil')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SearchBar(),

          const SizedBox(height: 28),

          const Text(
            'Escolha uma música',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 26),

          const Text(
            'Tocadas Recentemente',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          _RecentSongs(songs: songs),

          const SizedBox(height: 22),

          _SongSection(
            title: 'Fácil',
            songs: faceis,
          ),

          _SongSection(
            title: 'Médio',
            songs: medios,
          ),

          _SongSection(
            title: 'Difícil',
            songs: dificeis,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF232136),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF39374A),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text(
                'Procurar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Container(
            width: 43,
            height: 43,
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF9B6DDA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search,
              color: Color(0xFF171522),
              size: 27,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSongs extends StatelessWidget {
  final List<Song> songs;

  const _RecentSongs({
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    final recentSongs = songs.take(3).toList();

    if (recentSongs.isEmpty) {
      return const Text(
        'Nenhuma música encontrada.',
        style: TextStyle(color: Colors.white70),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recentSongs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final song = recentSongs[index];

          return SizedBox(
            width: 103,
            child: Column(
              children: [
                Container(
                  width: 103,
                  height: 103,
                  decoration: BoxDecoration(
                    color: const Color(0xFF232136),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFF39374A),
                    ),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white54,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  song.titulo,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SongSection extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const _SongSection({
    required this.title,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),

        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 18),

        if (songs.isEmpty)
          const Text(
            'Nenhuma música disponível.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),

        ...songs.map(
          (song) => _SongCard(song: song),
        ),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;

  const _SongCard({
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PerformancePage(
              song: song,
            ),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 103,
            height: 103,
            decoration: BoxDecoration(
              color: const Color(0xFF232136),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: const Color(0xFF39374A),
              ),
            ),
            child: const Icon(
              Icons.music_note,
              color: Colors.white54,
              size: 35,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    song.compositor,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '${song.bpmPadrao} BPM',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
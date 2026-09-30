import 'package:flutter/material.dart';
import 'package:flutter_app/features/performance/presentation/pages/performance_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_app/features/songs/presentation/providers/songs_provider.dart';

import '../../../auth/presentation/pages/user_profile_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../configuration/presentation/pages/configuration_page.dart';
import '../../../connection/presentation/pages/connection_page.dart';
import '../../../connection/presentation/providers/connection_provider.dart';
import '../../../gamification/presentation/pages/gamification_page.dart';
import '../../../history/presentation/providers/history_provider.dart';

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

class _SongsContent extends StatefulWidget {
  final List<Song> songs;

  const _SongsContent({
    required this.songs,
  });

  @override
  State<_SongsContent> createState() => _SongsContentState();
}

class _SongsContentState extends State<_SongsContent> {
  // Texto digitado na busca.
  String query = '';

  // Remove acentos para a busca ignorar "é", "ã" etc.
  String _normalize(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var result = text.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final term = _normalize(query.trim());

    // Filtra por título ou compositor.
    final songs = term.isEmpty
        ? widget.songs
        : widget.songs
            .where((song) =>
                _normalize(song.titulo).contains(term) ||
                _normalize(song.compositor).contains(term))
            .toList();

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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com saudação e botão de perfil.
          const _Header(),

          const SizedBox(height: 24),

          _SearchBar(
            onChanged: (value) => setState(() => query = value),
          ),

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

          _RecentSongs(songs: widget.songs),

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

// ==========================================================
// CABEÇALHO COM BOTÃO DE PERFIL
// ==========================================================

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Saudação à esquerda.
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pronto para praticar?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Troféus.
            _CircleButton(
              icon: Icons.emoji_events_outlined,
              tooltip: 'Troféus',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GamificationPage(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Configurações.
            _CircleButton(
              icon: Icons.tune,
              tooltip: 'Configurações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConfigurationPage(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Botão de perfil à direita.
            _CircleButton(
              icon: Icons.person_outline,
              tooltip: 'Meu perfil',
              onTap: () {
                // Abre a tela de perfil do usuário.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserProfilePage(),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Status do dispositivo embarcado.
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ConnectionPage(pushed: true),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF232136),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF39374A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  connection.isConnected
                      ? (connection.isSimulated ? Icons.smart_toy_outlined : Icons.sensors)
                      : Icons.sensors_off,
                  color: connection.isConnected ? Colors.greenAccent : Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  connection.isConnected
                      ? connection.device!.name
                      : 'Nenhum dispositivo conectado',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF232136),
        shape: const CircleBorder(
          side: BorderSide(
            color: Color(0xFF39374A),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.onChanged,
  });

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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: TextField(
                onChanged: onChanged,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                cursorColor: const Color(0xFF9B6DDA),
                decoration: const InputDecoration(
                  hintText: 'Procurar',
                  hintStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
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

class _RecentSongs extends ConsumerWidget {
  final List<Song> songs;

  const _RecentSongs({
    required this.songs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    // Músicas das execuções mais recentes do usuário.
    final recentIds = user == null
        ? const <String>[]
        : ref.watch(recentSongIdsProvider(user.id)).value ?? const <String>[];

    final recentSongs = [
      for (final id in recentIds)
        ...songs.where((song) => song.id == id),
    ];

    if (recentSongs.isEmpty) {
      return const Text(
        'Nenhuma música tocada ainda.',
        style: TextStyle(color: Colors.white70),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recentSongs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final song = recentSongs[index];

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerformancePage(song: song),
              ),
            ),
            child: SizedBox(
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
      ),
    );
  }
}
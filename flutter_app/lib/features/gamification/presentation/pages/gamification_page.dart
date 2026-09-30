import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/trophy_progress.dart';
import '../providers/gamification_provider.dart';

// Ícones disponíveis para os troféus (campo "icone" no Firestore).
class TrophyIcons {
  static IconData of(String name) => switch (name) {
        'music_note' => Icons.music_note,
        'hearing' => Icons.hearing,
        'star' => Icons.star,
        'av_timer' => Icons.av_timer,
        'repeat' => Icons.repeat,
        'explore' => Icons.explore,
        'whatshot' => Icons.whatshot,
        'school' => Icons.school,
        'favorite' => Icons.favorite,
        _ => Icons.emoji_events,
      };
}

// Troféus conquistados e disponíveis (RU15).
class GamificationPage extends ConsumerWidget {
  const GamificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Troféus'),
      ),

      body: SafeArea(
        child: user == null
            ? const Center(
                child: Text(
                  'Usuário não autenticado.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : ref.watch(trophyProgressProvider(user.id)).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erro ao carregar troféus: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  data: (trophies) => _TrophyGrid(trophies: trophies),
                ),
      ),
    );
  }
}

class _TrophyGrid extends StatelessWidget {
  final List<TrophyProgress> trophies;

  const _TrophyGrid({required this.trophies});

  @override
  Widget build(BuildContext context) {
    final unlocked = trophies.where((t) => t.unlocked).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1922),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unlocked de ${trophies.length} troféus',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: trophies.isEmpty ? 0 : unlocked / trophies.length,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => TrophyCard(progress: trophies[index]),
              childCount: trophies.length,
            ),
          ),
        ),
      ],
    );
  }
}

// Cartão de um troféu (também usado no resultado da execução).
class TrophyCard extends StatelessWidget {
  final TrophyProgress progress;

  const TrophyCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final trophy = progress.trophy;
    final unlocked = progress.unlocked;
    final date = progress.conquest?.dataConquista;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF232136),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? Colors.amber.withValues(alpha: 0.7) : const Color(0xFF39374A),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? Colors.amber.withValues(alpha: 0.18) : Colors.white10,
            ),
            child: Icon(
              unlocked ? TrophyIcons.of(trophy.icone) : Icons.lock_outline,
              color: unlocked ? Colors.amber : Colors.white38,
              size: 34,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            trophy.titulo,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? Colors.white : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              trophy.descricao,
              textAlign: TextAlign.center,
              overflow: TextOverflow.fade,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          if (unlocked && date != null)
            Text(
              'Conquistado em ${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}',
              style: const TextStyle(color: Colors.amber, fontSize: 11),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: const Color(0xFF9B6DDA),
              ),
            ),
        ],
      ),
    );
  }
}

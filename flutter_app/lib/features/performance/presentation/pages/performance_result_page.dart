import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../history/domain/entities/performance_history.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../history/presentation/widgets/performance_history_list.dart';

import '../../../gamification/domain/entities/trophy.dart';
import '../../../gamification/presentation/pages/gamification_page.dart';

import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';
import '../../../score/domain/services/score_analyzer.dart';
import '../../../score/presentation/widgets/score_result_widget.dart';

import '../../../songs/domain/entities/song.dart';

import '../widgets/music_history_widget.dart';
import '../widgets/performance_chart.dart';
import '../widgets/performance_score_card.dart';

import 'performance_page.dart';

class PerformanceResultPage extends ConsumerStatefulWidget {
  // Música que acabou de ser executada.
  final Song song;

  // Precisão da execução atual.
  final double precision;

  // Quantidade de notas executadas.
  final int notesPlayed;

  // Avaliação detalhada (altura, ritmo, frases).
  final ScoreResult? result;

  // Partitura executada e resultado de cada nota.
  final ScoreStructure? structure;
  final Map<int, NoteFeedback> feedback;

  // Troféus conquistados nesta execução.
  final List<Trophy> newTrophies;

  // Maior sequência de acertos.
  final int? bestStreak;

  const PerformanceResultPage({
    super.key,
    required this.song,
    required this.precision,
    required this.notesPlayed,
    this.result,
    this.structure,
    this.feedback = const {},
    this.newTrophies = const [],
    this.bestStreak,
  });

  @override
  ConsumerState<PerformanceResultPage> createState() =>
      _PerformanceResultPageState();
}

class _PerformanceResultPageState extends ConsumerState<PerformanceResultPage> {
  // 0 = Histórico.
  // 1 = Evolução.
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    // Recupera o usuário atualmente logado.
    final user = ref.watch(authProvider).user;

    // Se não houver usuário logado,
    // não conseguimos buscar o histórico.
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),

        body: Center(
          child: Text(
            'Usuário não autenticado.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Cria os parâmetros da consulta.
    final historyParams = HistoryParams(
      userId: user.id,
      songId: widget.song.id,
    );

    // Busca o histórico da música
    // para o usuário atual.
    final historyAsync = ref.watch(historyProvider(historyParams));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          // Em telas largas (web) o conteúdo fica centralizado.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // Título da página.
                  const Text(
                    'Resumo da performance',

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Card com a pontuação atual.
                  PerformanceScoreCard(
                    precision: widget.precision,

                    notesPlayed: widget.notesPlayed,

                    bestStreak: widget.bestStreak,
                  ),

                  const SizedBox(height: 16),

                  // Precisão de altura e ritmo (RU13).
                  if (widget.result != null)
                    ScoreResultWidget(result: widget.result!),

                  // Troféus conquistados agora (RFA10).
                  if (widget.newTrophies.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    _buildNewTrophies(),
                  ],

                  const SizedBox(height: 24),

                  // Abas.
                  _buildTabs(),

                  const SizedBox(height: 20),

                  // Aba selecionada.
                  if (selectedTab == 0)
                    // Histórico = notas executadas
                    // durante a performance atual.
                    _buildHistory()
                  else
                    // Evolução = histórico das
                    // execuções anteriores.
                    _buildEvolution(historyAsync),

                  const SizedBox(height: 30),

                  // Reiniciar a mesma música (RU16).
                  SizedBox(
                    width: double.infinity,

                    height: 55,

                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerformancePage(song: widget.song),
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),

                      icon: const Icon(Icons.replay),

                      label: const Text('TOCAR NOVAMENTE'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botão para voltar ao início.
                  SizedBox(
                    width: double.infinity,

                    height: 55,

                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },

                      child: const Text('INÍCIO'),
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

  // -------------------------------------------------------
  // ABAS
  // -------------------------------------------------------

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(child: _buildTab(title: 'Histórico', index: 0)),

        Expanded(child: _buildTab(title: 'Evolução', index: 1)),
      ],
    );
  }

  Widget _buildTab({required String title, required int index}) {
    final selected = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),

        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Colors.deepPurple : Colors.white24,

              width: 2,
            ),
          ),
        ),

        child: Text(
          title,

          textAlign: TextAlign.center,

          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // ABA HISTÓRICO
  // -------------------------------------------------------

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Notas executadas',

          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Notas da execução atual coloridas
        // sobre a partitura.
        MusicHistoryWidget(
          structure: widget.structure,
          feedback: widget.feedback,
        ),

        const SizedBox(height: 12),

        // Legenda das cores.
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            _Legend(color: Colors.green, label: 'Correto'),

            SizedBox(width: 20),

            _Legend(color: Colors.orange, label: 'Aproximado'),

            SizedBox(width: 20),

            _Legend(color: Colors.red, label: 'Incorreto'),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // ABA EVOLUÇÃO
  // -------------------------------------------------------

  Widget _buildEvolution(AsyncValue<List<PerformanceHistory>> historyAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Histórico de execuções',

          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        // Trata os três estados possíveis
        // da consulta ao Firestore.
        historyAsync.when(
          // Enquanto busca os dados.
          loading: () {
            return const Center(child: CircularProgressIndicator());
          },

          // Se ocorrer algum erro.
          error: (error, stackTrace) {
            return Text(
              'Erro ao carregar histórico: '
              '$error',

              style: const TextStyle(color: Colors.red),
            );
          },

          // Quando os dados chegam.
          data: (history) {
            // Gráfico de evolução a partir da
            // 10ª execução da mesma música (RFA11).
            const minimum = 10;

            final values = history.reversed.map((h) => h.score).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.all(16),

                  margin: const EdgeInsets.only(bottom: 16),

                  decoration: BoxDecoration(
                    color: const Color(0xFF191827),
                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: history.length >= minimum
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evolução da pontuação',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PerformanceChart(values: values),
                          ],
                        )
                      : Text(
                          'O gráfico de evolução aparece a partir da '
                          '$minimum.ª execução desta música. '
                          'Faltam ${minimum - history.length}.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                ),

                PerformanceHistoryList(history: history),
              ],
            );
          },
        ),
      ],
    );
  }

  // Destaque dos troféus conquistados.
  Widget _buildNewTrophies() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GamificationPage()),
        );
      },

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
        ),

        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 40),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    widget.newTrophies.length == 1
                        ? 'Novo troféu conquistado!'
                        : '${widget.newTrophies.length} novos troféus!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.newTrophies.map((t) => t.titulo).join(', '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// LEGENDA
// ---------------------------------------------------------

class _Legend extends StatelessWidget {
  final Color color;

  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,

          height: 10,

          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 5),

        Text(
          label,

          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

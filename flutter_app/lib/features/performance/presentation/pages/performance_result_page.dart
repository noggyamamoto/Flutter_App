import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../history/domain/entities/performance_history.dart';
import '../../../history/domain/services/evolution_stats.dart';
import '../../../history/presentation/pages/past_performance_page.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../history/presentation/widgets/evolution_panel.dart';
import '../../../history/presentation/widgets/performance_history_list.dart';

import '../../../gamification/domain/entities/trophy.dart';
import '../../../gamification/presentation/pages/gamification_page.dart';

import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/entities/score_result.dart';
import '../../../score/domain/services/score_analyzer.dart';
import '../../../score/presentation/widgets/score_result_widget.dart';

import '../../../songs/domain/entities/song.dart';

import '../widgets/feedback_colors.dart';
import '../widgets/music_history_widget.dart';
import '../widgets/performance_score_card.dart';

import 'performance_page.dart';

// Resumo da performance: exibido ao fim da execução e, com `execution`,
// ao abrir uma execução anterior pelo histórico (mesma tela, com os dados
// salvos daquela execução).
class PerformanceResultPage extends ConsumerStatefulWidget {
  // Música executada.
  final Song song;

  // Precisão da execução.
  final double precision;

  // Quantidade de notas executadas (execuções antigas podem não ter).
  final int? notesPlayed;

  // Avaliação detalhada (altura, ritmo, frases).
  final ScoreResult? result;

  // Partitura executada e resultado de cada nota.
  final ScoreStructure? structure;
  final Map<int, NoteFeedback> feedback;

  // Troféus conquistados nesta execução.
  final List<Trophy> newTrophies;

  // Maior sequência de acertos.
  final int? bestStreak;

  // ID da execução salva agora (destacada na aba Evolução).
  final String? executionId;

  // Execução anterior aberta pelo histórico (null = execução que acabou de
  // terminar).
  final PerformanceHistory? execution;

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
    this.executionId,
    this.execution,
  });

  // Mesma tela, com os dados salvos de uma execução anterior.
  factory PerformanceResultPage.fromHistory({
    Key? key,
    required Song song,
    required PerformanceHistory execution,
    ScoreStructure? structure,
  }) {
    return PerformanceResultPage(
      key: key,
      song: song,
      precision: execution.score,
      notesPlayed: execution.notesPlayed,
      result: execution.scoreResult,
      structure: structure,
      feedback: execution.noteFeedback,
      bestStreak: execution.bestStreak,
      executionId: execution.executionId,
      execution: execution,
    );
  }

  @override
  ConsumerState<PerformanceResultPage> createState() =>
      _PerformanceResultPageState();
}

class _PerformanceResultPageState extends ConsumerState<PerformanceResultPage> {
  // 0 = Histórico.
  // 1 = Evolução.
  int selectedTab = 0;

  bool get _isPast => widget.execution != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Recupera o usuário atualmente logado.
    final user = ref.watch(authProvider).user;

    // Se não houver usuário logado,
    // não conseguimos buscar o histórico.
    if (user == null) {
      return Scaffold(
        backgroundColor: colors.background,

        body: Center(
          child: Text(
            'Usuário não autenticado.',
            style: TextStyle(color: colors.textPrimary),
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
      backgroundColor: colors.background,

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
                  _buildHeader(colors, historyAsync.asData?.value),

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
                  if (widget.newTrophies.isNotEmpty && !_isPast) ...[
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
                        // Fecha os resumos abertos (o atual e os do
                        // histórico) e abre a execução.
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PerformancePage(song: widget.song),
                          ),
                          (route) => route.isFirst,
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
    final colors = context.colors;

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
              color: selected ? Colors.deepPurple : colors.outline,

              width: 2,
            ),
          ),
        ),

        child: Text(
          title,

          textAlign: TextAlign.center,

          style: TextStyle(
            color: selected ? colors.textPrimary : colors.textMuted,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // CABEÇALHO
  // -------------------------------------------------------

  Widget _buildHeader(AppColors colors, List<PerformanceHistory>? history) {
    final title = Text(
      'Resumo da performance',
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );

    final execution = widget.execution;
    if (execution == null) return title;

    // Execução anterior: número e data da execução, com volta ao resumo
    // anterior.
    final ordinal = history == null
        ? null
        : EvolutionStats.from(history).ordinalOf(execution.executionId);

    return Row(
      children: [
        IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 4),
              Text(
                '${ordinal != null ? '$ordinalª execução · ' : ''}'
                '${formatExecutionDate(execution.date)} · ${widget.song.titulo}',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // ABA HISTÓRICO
  // -------------------------------------------------------

  Widget _buildHistory() {
    final colors = context.colors;

    // Execução salva antes do registro nota a nota.
    final noDetails = _isPast && !widget.execution!.hasNoteDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'Notas executadas',

          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (noDetails)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Esta execução foi salva antes do registro nota a nota. '
                    'As próximas execuções mostram aqui cada nota colorida '
                    'sobre a partitura.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Notas da execução coloridas
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
              _Legend(color: FeedbackColors.correct, label: 'Correto'),

              SizedBox(width: 20),

              _Legend(color: FeedbackColors.approximate, label: 'Aproximado'),

              SizedBox(width: 20),

              _Legend(color: FeedbackColors.incorrect, label: 'Incorreto'),
            ],
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------
  // ABA EVOLUÇÃO
  // -------------------------------------------------------

  Widget _buildEvolution(AsyncValue<List<PerformanceHistory>> historyAsync) {
    // Trata os três estados possíveis
    // da consulta ao Firestore.
    return historyAsync.when(
      // Enquanto busca os dados.
      loading: () {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      },

      // Se ocorrer algum erro.
      error: (error, stackTrace) {
        return Text(
          'Erro ao carregar histórico: '
          '$error',

          style: const TextStyle(color: FeedbackColors.incorrect),
        );
      },

      // Quando os dados chegam: resumo, gráfico (a partir da 10ª
      // execução – RFA11) e lista das execuções.
      data: (history) {
        return EvolutionPanel(
          history: history,
          currentExecutionId: widget.executionId,
          onOpen: _openExecution,
        );
      },
    );
  }

  // Abre uma execução do histórico na mesma tela do fim da execução.
  void _openExecution(PerformanceHistory execution) {
    if (execution.executionId == widget.executionId) {
      setState(() => selectedTab = 0);
      return;
    }

    final route = MaterialPageRoute<void>(
      builder: (_) => PastPerformancePage(song: widget.song, execution: execution),
    );

    // Entre execuções anteriores, troca a tela (a volta leva ao resumo da
    // execução que acabou de terminar).
    if (_isPast) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  // Destaque dos troféus conquistados.
  Widget _buildNewTrophies() {
    final colors = context.colors;

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
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.newTrophies.map((t) => t.titulo).join(', '),
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right, color: colors.textMuted),
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

          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

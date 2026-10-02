import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

import 'package:flutter_app/features/performance/domain/entities/performance_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../configuration/presentation/pages/configuration_page.dart';
import '../../../configuration/presentation/providers/configuration_provider.dart';

import '../../../connection/presentation/pages/connection_page.dart';
import '../../../connection/presentation/providers/connection_provider.dart';

import '../../../gamification/domain/entities/trophy.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';

import '../../../history/presentation/providers/history_provider.dart';

import '../../../score/domain/entities/expected_note.dart';

import '../../../songs/domain/entities/song.dart';

import '../providers/performance_provider.dart';

import '../widgets/countdown_widget.dart';

import '../widgets/feedback_colors.dart';

import '../widgets/score_display.dart';

import '../widgets/judgement_badge.dart';

import '../widgets/note_guide.dart';

import '../widgets/performance_hud.dart';

import 'performance_result_page.dart';


class PerformancePage
    extends ConsumerStatefulWidget {

  // Música que será executada.
  final Song song;

  const PerformancePage({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<PerformancePage>
      createState() =>
          _PerformancePageState();
}


class _PerformancePageState
    extends ConsumerState<PerformancePage> {

  // Evita salvar a mesma execução duas vezes.
  bool _saving = false;

  @override
  void initState() {

    super.initState();

    // Carrega a partitura depois que
    // a tela estiver inicializada.
    Future.microtask(() {

      ref
          .read(
            performanceProvider
                .notifier,
          )
          .loadSong(
            widget.song,
          );
    });
  }


  @override
  Widget build(
    BuildContext context,
  ) {

    // Observa o estado atual da performance.
    final state =
        ref.watch(
      performanceProvider,
    );

    // Ao terminar, salva e abre o resultado.
    ref.listen<PerformanceState>(
      performanceProvider,
      (previous, next) {
        if (previous?.status != PerformanceStatus.finished &&
            next.status == PerformanceStatus.finished) {
          _finishPerformance(next);
        }
      },
    );

    final active = state.status == PerformanceStatus.countdown ||
        state.status == PerformanceStatus.running;

    return PopScope(
      canPop: !active,

      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          ref.read(performanceProvider.notifier).reset();
          return;
        }
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) {
          await ref.read(performanceProvider.notifier).reset();
          navigator.pop();
        }
      },

      child: Scaffold(

        backgroundColor:
            const Color(0xFF0F0E17),

        body: SafeArea(

          child: _buildContent(
            state,
          ),
        ),
      ),
    );
  }


  Future<bool> _confirmExit() async {

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: const Text(
            'Interromper a execução?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'O progresso deste trecho não será salvo.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Continuar tocando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Sair',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    return confirm == true;
  }


  Widget _buildContent(
    PerformanceState state,
  ) {

    switch (state.status) {

      case PerformanceStatus.initial:

      case PerformanceStatus.loading:

        return const Center(
          child:
              CircularProgressIndicator(),
        );


      case PerformanceStatus.error:

        return _buildError(
          state.errorMessage,
        );


      case PerformanceStatus.ready:

      case PerformanceStatus.countdown:

      case PerformanceStatus.running:

      case PerformanceStatus.phraseFailed:

        return _buildPerformance(
          state,
        );


      case PerformanceStatus.finished:

        return const Center(
          child:
              CircularProgressIndicator(),
        );
    }
  }


  Widget _buildError(
    String? message,
  ) {

    return Center(

      child: Padding(

        padding:
            const EdgeInsets.all(24),

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Não foi possível carregar a partitura.',

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message ?? '',

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color: Colors.white70,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            ElevatedButton(

              onPressed: () {

                ref
                    .read(
                      performanceProvider
                          .notifier,
                    )
                    .loadSong(
                      widget.song,
                    );
              },

              child:
                  const Text(
                'Tentar novamente',
              ),
            ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Voltar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // -------------------------------------------------------
  // TELA PRINCIPAL (pronto, contagem, execução, frase reprovada)
  //
  // Layout inspirado nos apps de prática musical (Simply Piano,
  // Yousician): progresso por trechos no topo, HUD com precisão e
  // sequência de acertos, partitura em destaque com cursor e selos de
  // avaliação sobre as notas, guia da próxima nota com teclado e
  // controles na base. Em telas largas (web/desktop) o HUD e o guia
  // ficam em um painel lateral.
  // -------------------------------------------------------

  static const double _wideBreakpoint = 900;

  Widget _buildPerformance(
    PerformanceState state,
  ) {

    return LayoutBuilder(
      builder: (context, constraints) {

        final wide = constraints.maxWidth >= _wideBreakpoint;
        final showGuide = state.status == PerformanceStatus.countdown ||
            state.status == PerformanceStatus.running;

        // Em telas baixas (celular deitado) o teclado guia é ocultado.
        final roomForGuide = constraints.maxHeight >= 640;

        final scoreCard = _buildScoreCard(state, wide: wide);

        if (wide) {
          return Column(
            children: [
              _buildTopBar(state),
              _buildProgress(state),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: scoreCard),
                    SizedBox(
                      width: 340,
                      child: _buildSidePanel(state),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Telas baixas (celular deitado): HUD resumido na barra superior.
        final short = constraints.maxHeight < 520;

        return Column(
          children: [
            _buildTopBar(state, inlineStats: short),
            _buildProgress(state),
            if (!short) _buildHud(state),
            Expanded(child: scoreCard),
            if (showGuide && roomForGuide)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _buildGuide(state, compact: true),
              ),
            _buildControls(state),
          ],
        );
      },
    );
  }


  // Próxima nota esperada (ainda sem avaliação) a partir do cursor.
  ExpectedNote? _nextExpected(PerformanceState state) {

    final structure = state.structure!;
    final cursor = state.cursorBeat ?? structure.phrases[state.viewPhrase].startBeat;

    for (final note in structure.expectedNotes) {
      if (note.phraseIndex < state.viewPhrase) continue;
      if (note.scoreNoteIds.any(state.feedback.containsKey)) continue;
      if (note.endBeat <= cursor) continue;
      return note;
    }
    return null;
  }


  Widget _buildTopBar(
    PerformanceState state, {
    bool inlineStats = false,
  }) {

    final connection = ref.watch(connectionProvider);
    final ready = state.status == PerformanceStatus.ready;
    final score = state.structure!.score;

    return Padding(

      padding:
          const EdgeInsets.fromLTRB(4, 6, 8, 0),

      child: Row(

        children: [

          IconButton(
            tooltip: 'Sair',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  widget.song.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  'Trecho ${state.viewPhrase + 1} de ${state.structure!.phrases.length}'
                  ' · ${score.beatsPerBar}/${score.beatType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (inlineStats && state.status != PerformanceStatus.ready) ...[
            AccuracyRing(precision: state.precision, size: 36),
            const SizedBox(width: 12),
            StreakCounter(streak: state.streak),
            const SizedBox(width: 12),
            Text(
              '${state.bpm} BPM · ${_formatElapsed(state.elapsed)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 12),
          ],

          // Status do dispositivo.
          _DevicePill(
            connected: connection.isConnected,
            simulated: connection.isSimulated,
            name: connection.device?.name,
            onTap: ready ? _openConnection : null,
          ),

          if (ready)
            IconButton(
              tooltip: 'Configurações',
              onPressed: _openSettings,
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }


  Widget _buildProgress(
    PerformanceState state,
  ) {

    final structure = state.structure!;
    final ready = state.status == PerformanceStatus.ready;
    final notifier = ref.read(performanceProvider.notifier);
    final phrase = structure.phrases[state.viewPhrase];
    final cursor = state.cursorBeat;
    final progress = cursor == null
        ? 0.0
        : ((cursor - phrase.startBeat) / phrase.durationBeats).clamp(0.0, 1.0);

    return Padding(

      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),

      child: Row(

        children: [

          if (ready)
            _RoundIcon(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Trecho anterior',
              onTap: state.viewPhrase > 0 ? () => notifier.showPhrase(state.viewPhrase - 1) : null,
            ),

          Expanded(
            child: PhraseProgressBar(
              phraseCount: structure.phrases.length,
              currentPhrase: state.viewPhrase,
              currentProgress: progress,
              phraseScores: state.phraseScores,
              onTap: ready ? notifier.showPhrase : null,
            ),
          ),

          if (ready)
            _RoundIcon(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Próximo trecho',
              onTap: state.viewPhrase < structure.phrases.length - 1
                  ? () => notifier.showPhrase(state.viewPhrase + 1)
                  : null,
            ),
        ],
      ),
    );
  }


  // HUD horizontal (celular): precisão, sequência, andamento e tempo.
  Widget _buildHud(
    PerformanceState state,
  ) {

    final settings = ref.watch(configurationProvider);
    final active = state.status != PerformanceStatus.ready;

    return Padding(

      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [

          HudStat(
            label: 'PRECISÃO',
            value: AccuracyRing(precision: state.precision, size: 46, active: active),
          ),

          HudStat(
            label: 'SEQUÊNCIA',
            value: StreakCounter(streak: state.streak),
          ),

          HudStat(
            label: 'BPM',
            value: TempoPill(
              bpm: state.bpm,
              beatInBar: state.beatInBar,
              beatsPerBar: state.structure!.score.beatsPerBar,
              showBeats: settings.metronomeVisual && state.status == PerformanceStatus.running,
              slowedDown: active && state.bpm < state.initialBpm,
            ),
          ),

          HudStat(
            label: 'TEMPO',
            value: Text(
              _formatElapsed(state.elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Painel lateral (web/desktop).
  Widget _buildSidePanel(
    PerformanceState state,
  ) {

    final settings = ref.watch(configurationProvider);
    final active = state.status != PerformanceStatus.ready;
    final showGuide = state.status == PerformanceStatus.countdown ||
        state.status == PerformanceStatus.running;

    return Padding(

      padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          _Panel(
            child: Column(
              children: [
                AccuracyRing(precision: state.precision, size: 96, active: active),
                const SizedBox(height: 6),
                const Text('Precisão', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    HudStat(label: 'SEQUÊNCIA', value: StreakCounter(streak: state.streak)),
                    HudStat(
                      label: 'BPM',
                      value: TempoPill(
                        bpm: state.bpm,
                        beatInBar: state.beatInBar,
                        beatsPerBar: state.structure!.score.beatsPerBar,
                        showBeats: settings.metronomeVisual && state.status == PerformanceStatus.running,
                        slowedDown: active && state.bpm < state.initialBpm,
                      ),
                    ),
                    HudStat(
                      label: 'TEMPO',
                      value: Text(
                        _formatElapsed(state.elapsed),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (showGuide)
            _Panel(child: _buildGuide(state, compact: false)),

          const Spacer(),

          _buildControls(state, inPanel: true),
        ],
      ),
    );
  }


  Widget _buildGuide(
    PerformanceState state, {
    required bool compact,
  }) {

    return NoteGuide(
      expectedMidi: _nextExpected(state)?.midi,
      playedMidi: state.lastPlayedMidi,
      playedFeedback: state.lastFeedback,
      compact: compact,
    );
  }


  Widget _buildScoreCard(
    PerformanceState state, {
    required bool wide,
  }) {

    final structure = state.structure!;
    final settings = ref.watch(configurationProvider);
    final phrase = structure.phrases[state.viewPhrase];
    final running = state.status == PerformanceStatus.running ||
        state.status == PerformanceStatus.countdown;
    final next = running ? _nextExpected(state) : null;

    return Padding(

      padding: EdgeInsets.fromLTRB(wide ? 16 : 10, wide ? 12 : 4, wide ? 16 : 10, 4),

      child: ClipRRect(

        borderRadius: BorderRadius.circular(20),

        child: Stack(

          children: [

            Positioned.fill(

              child: Container(

                color: AppColors.paper,

                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),

                child: ScoreDisplay(

                  score: structure.score,

                  measureIndexes: phrase.measureIndexes,

                  noteColors: FeedbackColors.map(state.feedback),

                  activeNoteIds: next == null ? const {} : next.scoreNoteIds.toSet(),

                  cursorBeat: state.cursorBeat,

                  zoom: settings.zoom * (wide ? 1.15 : 1.0),

                  overlayBuilder: (context, layout) {
                    final judgement = state.judgement;
                    if (judgement == null || state.status != PerformanceStatus.running) {
                      return const SizedBox.shrink();
                    }
                    return JudgementBadge(judgement: judgement, layout: layout);
                  },
                ),
              ),
            ),

            // Contagem de entrada (RFA05).
            if (state.status == PerformanceStatus.countdown)
              Positioned.fill(
                child: CountdownWidget(
                  beat: state.countInBeat,
                  bar: state.countInBar,
                  beatsPerBar: structure.score.beatsPerBar,
                  totalBars: PerformanceNotifier.countInBars,
                ),
              ),

            // Tela de incentivo quando a frase fica abaixo de 50% (RFA08).
            if (state.status == PerformanceStatus.phraseFailed)
              Positioned.fill(
                child: _buildPhraseFailed(state),
              ),

            // Avisos (ex.: conexão perdida) somente fora da execução: durante a
            // contagem e a execução nada é sobreposto à partitura.
            if (state.message != null && state.status == PerformanceStatus.ready)
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                child: _buildMessage(state),
              ),
          ],
        ),
      ),
    );
  }


  // Aviso exibido antes de iniciar (ex.: conexão perdida, dispositivo não
  // conectado). Durante a execução nada é sobreposto à partitura.
  Widget _buildMessage(
    PerformanceState state,
  ) {

    final notifier = ref.read(performanceProvider.notifier);

    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              visualDensity: VisualDensity.compact,
              onPressed: notifier.dismissMessage,
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPhraseFailed(
    PerformanceState state,
  ) {

    final result = state.lastPhrase!;
    final notifier = ref.read(performanceProvider.notifier);
    final color = FeedbackColors.forScore(result.score);

    return Container(
      color: AppColors.background.withValues(alpha: 0.92),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AccuracyRing(precision: result.score, size: 88)),
              const SizedBox(height: 14),
              const Text(
                'Vamos praticar este trecho!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Você acertou ${result.score.round()}% do trecho '
                '${result.phraseIndex + 1}. A música parou aqui para você '
                'repetir com calma — cada tentativa conta!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Stat(label: 'Altura', value: '${result.pitchAccuracy.round()}%', color: color),
                  _Stat(label: 'Ritmo', value: '${result.rhythmAccuracy.round()}%', color: color),
                  _Stat(label: 'Perdidas', value: '${result.notesMissed}', color: color),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => notifier.retryPhrase(),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(
                    'Repetir trecho',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => notifier.retryPhrase(slower: true),
                  icon: const Icon(Icons.speed_rounded),
                  label: Text('Repetir mais devagar (${(state.bpm * 0.9).round()} BPM)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primarySoft,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => notifier.finish(completed: false),
                child: const Text(
                  'Encerrar e ver resultado',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  Widget _buildControls(
    PerformanceState state, {
    bool inPanel = false,
  }) {

    if (state.status == PerformanceStatus.ready) {
      return _buildStartControls(state, inPanel: inPanel);
    }

    if (state.status == PerformanceStatus.phraseFailed) {
      return const SizedBox(height: 16);
    }

    return Padding(

      padding: EdgeInsets.fromLTRB(inPanel ? 0 : 16, 10, inPanel ? 0 : 16, inPanel ? 0 : 14),

      child: Row(

        children: [

          // Notas tocadas até agora ou, se o trecho foi instável e o ajuste
          // automático está desligado, a sugestão de BPM (RFA09) – aqui, fora
          // da partitura, para não cobrir o trecho seguinte.
          Expanded(
            child: state.suggestedBpm != null
                ? _buildTempoSuggestion(state)
                : Text(
                    '${state.notesPlayed} notas tocadas',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
          ),

          // Finaliza a performance.
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => ref.read(performanceProvider.notifier).stop(),
              icon: const Icon(Icons.stop_rounded),
              label: const Text(
                'PARAR',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Sugestão de redução de andamento (RFA09) exibida nos controles.
  Widget _buildTempoSuggestion(
    PerformanceState state,
  ) {

    final notifier = ref.read(performanceProvider.notifier);

    return Row(
      children: [
        const Icon(Icons.speed_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: TextButton(
            onPressed: notifier.acceptTempoSuggestion,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.surface,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'Reduzir para ${state.suggestedBpm} BPM',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Dispensar',
          visualDensity: VisualDensity.compact,
          onPressed: notifier.dismissMessage,
          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
        ),
      ],
    );
  }


  Widget _buildStartControls(
    PerformanceState state, {
    bool inPanel = false,
  }) {

    final connection = ref.watch(connectionProvider);
    final notifier = ref.read(performanceProvider.notifier);

    return Padding(

      padding: EdgeInsets.fromLTRB(inPanel ? 0 : 20, 8, inPanel ? 0 : 20, inPanel ? 0 : 18),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          // Ajuste do andamento antes de começar.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Diminuir andamento',
                  onPressed: () => notifier.setBpm(state.bpm - 5),
                  icon: const Icon(Icons.remove_rounded, color: Colors.white70),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${state.bpm} BPM',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Aumentar andamento',
                  onPressed: () => notifier.setBpm(state.bpm + 5),
                  icon: const Icon(Icons.add_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(

            width:
                double.infinity,

            height:
                54,

            child: connection.isConnected
                ? ElevatedButton.icon(

                    onPressed: () {

                      notifier.start(fromPhrase: state.viewPhrase);
                    },

                    icon: const Icon(Icons.play_arrow_rounded, size: 28),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),

                    label: Text(

                      state.viewPhrase == 0
                          ? 'INICIAR'
                          : 'INICIAR DO TRECHO ${state.viewPhrase + 1}',

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _openConnection,
                    icon: const Icon(Icons.sensors_rounded),
                    label: const Text(
                      'CONECTAR DISPOSITIVO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
          ),
        ],
      ),
    );
  }


  void _openConnection() {

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConnectionPage(pushed: true),
      ),
    );
  }


  Future<void> _openSettings() async {

    final before = ref.read(configurationProvider).measuresPerPhrase;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ConfigurationPage(),
      ),
    );

    // Frases com outro tamanho: recarrega a partitura.
    if (mounted && ref.read(configurationProvider).measuresPerPhrase != before) {
      await ref.read(performanceProvider.notifier).loadSong(widget.song);
    }
  }


  // -------------------------------------------------------
  // FIM: SALVAR, TROFÉUS E RESULTADO
  // -------------------------------------------------------

  Future<void> _finishPerformance(
    PerformanceState state,
  ) async {

    if (_saving) return;

    _saving = true;

    final result = state.result;

    // Recupera o usuário atualmente autenticado.
    final user =
        ref.read(
      authProvider,
    ).user;

    var newTrophies = <Trophy>[];

    // Salva somente execuções em que o aluno chegou a tocar.
    if (user != null && result != null && result.notesExpected > 0) {

      try {

        // Salva a execução no Firestore.
        await ref
            .read(
              performanceProvider
                  .notifier,
            )
            .savePerformance(

          // UID do usuário.
          userId:
              user.id,

          // ID da partitura.
          songId:
              widget.song.id,

          // BPM inicial da execução.
          bpmInicial:
              state.initialBpm,

          // Pontuação geral.
          pontuacaoFinal:
              result.overall,
        );

        // Atualiza o histórico exibido no resultado, as músicas recentes e
        // o progresso dos troféus (a nova execução conta nos critérios).
        ref.invalidate(historyProvider(
          HistoryParams(userId: user.id, songId: widget.song.id),
        ));
        ref.invalidate(recentSongIdsProvider(user.id));
        ref.invalidate(trophyProgressProvider(user.id));

      } catch (e) {

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível salvar a execução: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }

      // Troféus (RFA10), somente para músicas concluídas. Separado do
      // salvamento: uma falha aqui não significa que a execução se perdeu.
      if (result.completed) {
        try {
          final hardSongs = await ref.read(hardSongIdsProvider.future);
          newTrophies = await ref.read(checkTrophiesProvider)(
            userId: user.id,
            songId: widget.song.id,
            hardSongIds: hardSongs,
          );
          ref.invalidate(trophyProgressProvider(user.id));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Não foi possível verificar os troféus: $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    }

    // Verifica se a página ainda existe
    // depois da operação assíncrona.
    if (!mounted) {
      return;
    }

    // Abre a página de resultado.
    Navigator.pushReplacement(

      context,

      MaterialPageRoute(

        builder: (_) =>
            PerformanceResultPage(

          // Música executada.
          song:
              widget.song,

          // Precisão real.
          precision:
              result?.overall ?? state.precision,

          // Quantidade real de notas.
          notesPlayed:
              state.notesPlayed,

          // Detalhes da avaliação.
          result:
              result,

          structure:
              state.structure,

          feedback:
              state.feedback,

          newTrophies:
              newTrophies,

          bestStreak:
              state.bestStreak,
        ),
      ),
    );
  }
}


class _Stat extends StatelessWidget {

  final String label;
  final String value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}


// Estado do dispositivo no topo da tela.
class _DevicePill extends StatelessWidget {

  final bool connected;
  final bool simulated;
  final String? name;
  final VoidCallback? onTap;

  const _DevicePill({
    required this.connected,
    required this.simulated,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    final color = connected ? AppColors.correct : AppColors.incorrect;
    final text = !connected ? 'Desconectado' : (simulated ? 'Demonstração' : 'Conectado');

    return Tooltip(
      message: connected ? (name ?? text) : 'Conectar dispositivo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connected
                    ? (simulated ? Icons.smart_toy_outlined : Icons.sensors_rounded)
                    : Icons.sensors_off_rounded,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}


class _RoundIcon extends StatelessWidget {

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {

    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
    );
  }
}


// Cartão do painel lateral.
class _Panel extends StatelessWidget {

  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}


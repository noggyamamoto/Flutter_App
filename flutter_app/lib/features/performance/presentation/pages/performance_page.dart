import 'package:flutter/material.dart';

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
import '../../../score/domain/entities/note_comparison.dart';

import '../../../songs/domain/entities/song.dart';

import '../providers/performance_provider.dart';

import '../widgets/countdown_widget.dart';

import '../widgets/feedback_colors.dart';

import '../widgets/score_display.dart';

import '../widgets/visual_metronome.dart';

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
  // -------------------------------------------------------

  Widget _buildPerformance(
    PerformanceState state,
  ) {

    final structure = state.structure!;
    final settings = ref.watch(configurationProvider);
    final phrase = structure.phrases[state.viewPhrase];

    return Column(

      children: [

        _buildHeader(state),

        _buildPhraseBar(state),

        Expanded(

          child: Stack(

            children: [

              Positioned.fill(

                child: Container(

                color:
                    Colors.white,

                padding: const EdgeInsets.only(top: 8),

                child:
                    ScoreDisplay(
                  score:
                      structure.score,

                  measureIndexes:
                      phrase.measureIndexes,

                  noteColors:
                      FeedbackColors.map(state.feedback),

                  evaluatedNoteIds:
                      structure.evaluatedNoteIds,

                  cursorBeat:
                      state.cursorBeat,

                  zoom:
                      settings.zoom,
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

              // Avisos (resultado da frase, sugestão de BPM, erros).
              if (state.message != null &&
                  state.status != PerformanceStatus.phraseFailed)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _buildMessage(state),
                ),
            ],
          ),
        ),

        _buildControls(state),
      ],
    );
  }


  Widget _buildHeader(
    PerformanceState state,
  ) {

    final connection = ref.watch(connectionProvider);
    final ready = state.status == PerformanceStatus.ready;

    return Container(

      padding:
          const EdgeInsets.fromLTRB(8, 8, 12, 4),

      child: Row(

        children: [

          IconButton(

            onPressed: () {

              Navigator.maybePop(
                context,
              );
            },

            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
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
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  '${state.structure!.score.beatsPerBar}/'
                  '${state.structure!.score.beatType} · ${state.bpm} BPM',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Status do dispositivo.
          IconButton(
            tooltip: connection.isConnected
                ? connection.device!.name
                : 'Conectar dispositivo',
            onPressed: ready ? _openConnection : null,
            icon: Icon(
              connection.isConnected
                  ? (connection.isSimulated ? Icons.smart_toy_outlined : Icons.sensors)
                  : Icons.sensors_off,
              color: connection.isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),

          if (ready)
            IconButton(
              tooltip: 'Configurações',
              onPressed: _openSettings,
              icon: const Icon(
                Icons.tune,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildPhraseBar(
    PerformanceState state,
  ) {

    final structure = state.structure!;
    final total = structure.phrases.length;
    final ready = state.status == PerformanceStatus.ready;
    final running = state.status == PerformanceStatus.running;
    final settings = ref.watch(configurationProvider);

    return Padding(

      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),

      child: Row(

        children: [

          if (ready)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: state.viewPhrase > 0
                  ? () => ref.read(performanceProvider.notifier).showPhrase(state.viewPhrase - 1)
                  : null,
              icon: const Icon(Icons.chevron_left, color: Colors.white),
            ),

          Flexible(
            child: Text(
              'Trecho ${state.viewPhrase + 1} de $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (ready)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: state.viewPhrase < total - 1
                  ? () => ref.read(performanceProvider.notifier).showPhrase(state.viewPhrase + 1)
                  : null,
              icon: const Icon(Icons.chevron_right, color: Colors.white),
            ),

          const Spacer(),

          // Última nota tocada, com a cor do resultado.
          if (running && state.lastPlayedMidi != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: (FeedbackColors.of(state.lastFeedback ?? NoteFeedback.pending) ??
                        Colors.white24)
                    .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ExpectedNote.noteName(state.lastPlayedMidi!),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),

          // Metrônomo visual (RU06).
          if (running && settings.metronomeVisual)
            VisualMetronome(
              beatInBar: state.beatInBar,
              beatsPerBar: structure.score.beatsPerBar,
            ),
        ],
      ),
    );
  }


  Widget _buildMessage(
    PerformanceState state,
  ) {

    final notifier = ref.read(performanceProvider.notifier);

    return Material(
      color: const Color(0xFF232136),
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        child: Row(
          children: [
            Icon(
              state.suggestedBpm != null ? Icons.speed : Icons.info_outline,
              color: const Color(0xFF9B6DDA),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            if (state.suggestedBpm != null)
              TextButton(
                onPressed: notifier.acceptTempoSuggestion,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple,
                ),
                child: Text('${state.suggestedBpm} BPM'),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: notifier.dismissMessage,
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
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

    return Container(
      color: const Color(0xFF0F0E17).withValues(alpha: 0.9),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.fitness_center, color: Color(0xFF9B6DDA), size: 56),
              const SizedBox(height: 16),
              const Text(
                'Vamos praticar este trecho!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Você acertou ${result.score.round()}% do trecho '
                '${result.phraseIndex + 1}. A música parou aqui para você '
                'repetir com calma — cada tentativa conta!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Stat(label: 'Altura', value: '${result.pitchAccuracy.round()}%'),
                  _Stat(label: 'Ritmo', value: '${result.rhythmAccuracy.round()}%'),
                  _Stat(label: 'Perdidas', value: '${result.notesMissed}'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => notifier.retryPhrase(),
                  icon: const Icon(Icons.replay),
                  label: const Text(
                    'Repetir trecho',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => notifier.retryPhrase(slower: true),
                  icon: const Icon(Icons.speed),
                  label: Text('Repetir mais devagar (${(state.bpm * 0.9).round()} BPM)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9B6DDA),
                    side: const BorderSide(color: Color(0xFF39374A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => notifier.finish(completed: false),
                child: const Text(
                  'Encerrar e ver resultado',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildControls(
    PerformanceState state,
  ) {

    if (state.status == PerformanceStatus.ready) {
      return _buildStartControls(state);
    }

    if (state.status == PerformanceStatus.phraseFailed) {
      return const SizedBox(height: 20);
    }

    // Converte o tempo decorrido para minutos.
    final minutes = state
        .elapsed
        .inMinutes
        .toString()
        .padLeft(2, '0');

    // Converte o tempo decorrido para segundos.
    final seconds =
        (state.elapsed.inSeconds %
                60)
            .toString()
            .padLeft(2, '0');

    return Container(

      padding:
          const EdgeInsets.all(20),

      child: Row(

        children: [

          // Mostra o tempo da performance.
          Text(

            '$minutes:$seconds',

            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),

          const SizedBox(width: 20),

          // Precisão parcial.
          Text(
            '${state.precision.round()}%',
            style: const TextStyle(
              color: Color(0xFF9B6DDA),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          ElevatedButton(

            style:
                ElevatedButton.styleFrom(

              backgroundColor:
                  Colors.deepPurple,

              foregroundColor:
                  Colors.white,
            ),

            // Finaliza a performance.
            onPressed: () =>
                ref.read(performanceProvider.notifier).stop(),

            child: const Text(
              'PARAR',
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStartControls(
    PerformanceState state,
  ) {

    final connection = ref.watch(connectionProvider);
    final notifier = ref.read(performanceProvider.notifier);

    return Padding(

      padding:
          const EdgeInsets.fromLTRB(20, 12, 20, 20),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          // Ajuste do andamento antes de começar.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => notifier.setBpm(state.bpm - 5),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
              ),
              Text(
                '${state.bpm} BPM',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => notifier.setBpm(state.bpm + 5),
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(

            width:
                double.infinity,

            height:
                55,

            child: connection.isConnected
                ? ElevatedButton(

                    onPressed: () {

                      notifier.start(fromPhrase: state.viewPhrase);
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),

                    child: Text(

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
                    icon: const Icon(Icons.sensors),
                    label: const Text(
                      'CONECTAR DISPOSITIVO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.deepPurple, width: 2),
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

        // Atualiza o histórico exibido no resultado.
        ref.invalidate(historyProvider(
          HistoryParams(userId: user.id, songId: widget.song.id),
        ));

        // Troféus (RFA10), somente para músicas concluídas.
        if (result.completed) {
          final hardSongs = await ref.read(hardSongIdsProvider.future);
          newTrophies = await ref.read(checkTrophiesProvider)(
            userId: user.id,
            songId: widget.song.id,
            hardSongIds: hardSongs,
          );
          ref.invalidate(trophyProgressProvider(user.id));
        }

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
        ),
      ),
    );
  }
}


class _Stat extends StatelessWidget {

  final String label;
  final String value;

  const _Stat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

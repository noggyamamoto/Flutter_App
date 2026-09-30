import 'package:flutter/material.dart';

import 'package:flutter_app/features/performance/domain/entities/performance_state.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../history/presentation/providers/history_provider.dart';

import '../../../songs/domain/entities/song.dart';

import '../providers/performance_provider.dart';

import '../widgets/countdown_widget.dart';

import '../widgets/score_display.dart';

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

    return Scaffold(

      backgroundColor:
          const Color(0xFF0F0E17),

      body: SafeArea(

        child: _buildContent(
          state,
        ),
      ),
    );
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

        return _buildReady(
          state,
        );


      case PerformanceStatus.countdown:

        return CountdownWidget(

          onFinished: () {

            ref
                .read(
                  performanceProvider
                      .notifier,
                )
                .startPerformance();
          },
        );


      case PerformanceStatus.running:

        return _buildRunning(
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
          ],
        ),
      ),
    );
  }


  Widget _buildReady(
    PerformanceState state,
  ) {

    return Column(

      children: [

        _buildHeader(),

        Expanded(

          child: Container(

            width:
                double.infinity,

            color:
                Colors.white,

            child:
                ScoreDisplay(
              score:
                  state.score!,
            ),
          ),
        ),

        _buildStartButton(),
      ],
    );
  }


  Widget _buildRunning(
    PerformanceState state,
  ) {

    return Column(

      children: [

        _buildHeader(),

        Expanded(

          child: Container(

            width:
                double.infinity,

            color:
                Colors.white,

            child:
                ScoreDisplay(
              score:
                  state.score!,
            ),
          ),
        ),

        _buildRunningControls(
          state,
        ),
      ],
    );
  }


  Widget _buildHeader() {

    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),

      child: Row(

        children: [

          IconButton(

            onPressed: () {

              Navigator.pop(
                context,
              );
            },

            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),

          Expanded(

            child: Text(

              widget.song.titulo,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStartButton() {

    return Padding(

      padding:
          const EdgeInsets.all(20),

      child: SizedBox(

        width:
            double.infinity,

        height:
            55,

        child: ElevatedButton(

          onPressed: () {

            ref
                .read(
                  performanceProvider
                      .notifier,
                )
                .startCountdown();
          },

          child: const Text(

            'INICIAR',

            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildRunningControls(
    PerformanceState state,
  ) {

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

          const Spacer(),

          ElevatedButton(

            style:
                ElevatedButton.styleFrom(

              backgroundColor:
                  Colors.deepPurple,
            ),

            // Finaliza a performance.
            onPressed:
                _finishPerformance,

            child: const Text(
              'PARAR',
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _finishPerformance() async {

    // Finaliza a performance.
    ref
        .read(
          performanceProvider
              .notifier,
        )
        .finishPerformance();

    // Recupera o estado final da performance.
    final state =
        ref.read(
      performanceProvider,
    );

    // Recupera o usuário atualmente autenticado.
    final user =
        ref.read(
      authProvider,
    ).user;

    // Verifica se existe usuário logado.
    if (user == null) {

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Usuário não autenticado.',
          ),
        ),
      );

      return;
    }

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

      // BPM padrão da música.
      bpmInicial:
          widget.song.bpmPadrao,

      // Precisão da performance.
      pontuacaoFinal:
          state.precision,
    );

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
              state.precision,

          // Quantidade real de notas.
          notesPlayed:
              state.notesPlayed,
        ),
      ),
    );
  }
}
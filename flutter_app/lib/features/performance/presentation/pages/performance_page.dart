import 'package:flutter/material.dart';
import 'package:flutter_app/features/performance/domain/entities/performance_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../songs/domain/entities/song.dart';

import '../providers/performance_provider.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/score_display.dart';
import 'performance_result_page.dart';

class PerformancePage
    extends ConsumerStatefulWidget {
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

    Future.microtask(() {
      ref
          .read(
            performanceProvider
                .notifier,
          )
          .loadSong(widget.song);
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
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
              style: const TextStyle(
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
              child: const Text(
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
            width: double.infinity,
            color: Colors.white,
            child: ScoreDisplay(
              score: state.score!,
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
            width: double.infinity,
            color: Colors.white,
            child: ScoreDisplay(
              score: state.score!,
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
        width: double.infinity,
        height: 55,
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
    final minutes = state
        .elapsed.inMinutes
        .toString()
        .padLeft(2, '0');

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

  void _finishPerformance() {
    ref
        .read(
          performanceProvider
              .notifier,
        )
        .finishPerformance();

    final state =
        ref.read(
      performanceProvider,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PerformanceResultPage(
          precision:
              state.precision,
          notesPlayed:
              state.notesPlayed,
        ),
      ),
    );
  }
}
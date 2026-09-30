import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../history/domain/entities/performance_history.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../history/presentation/widgets/performance_history_list.dart';

import '../../../songs/domain/entities/song.dart';

import '../widgets/music_history_widget.dart';
import '../widgets/performance_score_card.dart';

class PerformanceResultPage
    extends ConsumerStatefulWidget {

  // Música que acabou de ser executada.
  final Song song;

  // Precisão da execução atual.
  final double precision;

  // Quantidade de notas executadas.
  final int notesPlayed;

  const PerformanceResultPage({
    super.key,
    required this.song,
    required this.precision,
    required this.notesPlayed,
  });

  @override
  ConsumerState<
      PerformanceResultPage>
      createState() =>
          _PerformanceResultPageState();
}

class _PerformanceResultPageState
    extends ConsumerState<
        PerformanceResultPage> {

  // 0 = Histórico.
  // 1 = Evolução.
  int selectedTab = 0;

  @override
  Widget build(
    BuildContext context,
  ) {

    // Recupera o usuário atualmente logado.
    final user =
        ref.watch(authProvider).user;

    // Se não houver usuário logado,
    // não conseguimos buscar o histórico.
    if (user == null) {

      return const Scaffold(
        backgroundColor:
            Color(0xFF0F0E17),

        body: Center(
          child: Text(
            'Usuário não autenticado.',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Cria os parâmetros da consulta.
    final historyParams =
        HistoryParams(
      userId: user.id,
      songId: widget.song.id,
    );

    // Busca o histórico da música
    // para o usuário atual.
    final historyAsync =
        ref.watch(
      historyProvider(historyParams),
    );

    return Scaffold(

      backgroundColor:
          const Color(0xFF0F0E17),

      body: SafeArea(

        child: SingleChildScrollView(

          padding:
              const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // Título da página.
              const Text(
                'Resumo da performance',

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // Card com a pontuação atual.
              PerformanceScoreCard(
                precision:
                    widget.precision,

                notesPlayed:
                    widget.notesPlayed,
              ),

              const SizedBox(
                height: 24,
              ),

              // Abas.
              _buildTabs(),

              const SizedBox(
                height: 20,
              ),

              // Aba selecionada.
              if (selectedTab == 0)

                // Histórico = notas executadas
                // durante a performance atual.
                _buildHistory()

              else

                // Evolução = histórico das
                // execuções anteriores.
                _buildEvolution(
                  historyAsync,
                ),

              const SizedBox(
                height: 30,
              ),

              // Botão para voltar ao início.
              SizedBox(

                width:
                    double.infinity,

                height: 55,

                child: ElevatedButton(

                  onPressed: () {

                    Navigator.popUntil(
                      context,
                      (route) =>
                          route.isFirst,
                    );
                  },

                  child:
                      const Text('INÍCIO'),
                ),
              ),
            ],
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

        Expanded(
          child: _buildTab(
            title: 'Histórico',
            index: 0,
          ),
        ),

        Expanded(
          child: _buildTab(
            title: 'Evolução',
            index: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTab({
    required String title,
    required int index,
  }) {

    final selected =
        selectedTab == index;

    return GestureDetector(

      onTap: () {

        setState(() {

          selectedTab = index;
        });
      },

      child: Container(

        padding:
            const EdgeInsets.symmetric(
          vertical: 14,
        ),

        decoration:
            BoxDecoration(

          border: Border(
            bottom: BorderSide(

              color: selected
                  ? Colors.deepPurple
                  : Colors.white24,

              width: 2,
            ),
          ),
        ),

        child: Text(

          title,

          textAlign:
              TextAlign.center,

          style: TextStyle(

            color: selected
                ? Colors.white
                : Colors.white54,

            fontWeight:
                FontWeight.bold,
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

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          'Notas executadas',

          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        // Mantém o widget que representa
        // as notas da execução atual.
        const MusicHistoryWidget(),

        const SizedBox(
          height: 12,
        ),

        // Legenda das cores.
        const Row(

          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            _Legend(
              color: Colors.green,
              label: 'Correto',
            ),

            SizedBox(
              width: 20,
            ),

            _Legend(
              color: Colors.orange,
              label: 'Aproximado',
            ),

            SizedBox(
              width: 20,
            ),

            _Legend(
              color: Colors.red,
              label: 'Incorreto',
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // ABA EVOLUÇÃO
  // -------------------------------------------------------

  Widget _buildEvolution(
    AsyncValue<List<PerformanceHistory>>
        historyAsync,
  ) {

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          'Histórico de execuções',

          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        // Trata os três estados possíveis
        // da consulta ao Firestore.
        historyAsync.when(

          // Enquanto busca os dados.
          loading: () {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          },

          // Se ocorrer algum erro.
          error: (
            error,
            stackTrace,
          ) {

            return Text(

              'Erro ao carregar histórico: '
              '$error',

              style: const TextStyle(
                color: Colors.red,
              ),
            );
          },

          // Quando os dados chegam.
          data: (history) {

            return PerformanceHistoryList(
              history: history,
            );
          },
        ),
      ],
    );
  }
}


// ---------------------------------------------------------
// LEGENDA
// ---------------------------------------------------------

class _Legend
    extends StatelessWidget {

  final Color color;

  final String label;

  const _Legend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return Row(
      children: [

        Container(

          width: 10,

          height: 10,

          decoration:
              BoxDecoration(

            color: color,

            shape:
                BoxShape.circle,
          ),
        ),

        const SizedBox(
          width: 5,
        ),

        Text(

          label,

          style:
              const TextStyle(

            color:
                Colors.white70,

            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
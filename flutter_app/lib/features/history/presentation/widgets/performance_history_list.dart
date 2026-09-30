import 'package:flutter/material.dart';

import '../../domain/entities/performance_history.dart';

class PerformanceHistoryList
    extends StatelessWidget {

  // Lista de execuções que será exibida.
  final List<PerformanceHistory> history;

  const PerformanceHistoryList({
    super.key,
    required this.history,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    // Caso o usuário ainda não tenha
    // nenhuma execução dessa música.
    if (history.isEmpty) {

      return const Padding(
        padding: EdgeInsets.all(24),

        child: Center(
          child: Text(
            'Nenhuma execução anterior encontrada.',
            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Lista das execuções.
    return ListView.builder(

      // Permite que a lista fique dentro
      // do SingleChildScrollView da página.
      shrinkWrap: true,

      // Evita conflito entre dois scrolls.
      physics:
          const NeverScrollableScrollPhysics(),

      // Quantidade de execuções.
      itemCount: history.length,

      itemBuilder: (
        context,
        index,
      ) {

        // Execução atual da lista.
        final performance =
            history[index];

        // Data da execução.
        final date =
            performance.date;

        // Formata a data.
        final dateText =
            '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}';

        // Formata o horário.
        final timeText =
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}';

        return Container(

          // Espaçamento entre os cards.
          margin: const EdgeInsets.only(
            bottom: 12,
          ),

          // Espaçamento interno.
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(

            color:
                const Color(0xFF191827),

            borderRadius:
                BorderRadius.circular(16),
          ),

          child: Row(
            children: [

              // Ícone da execução.
              const Icon(
                Icons.music_note,
                color: Colors.deepPurple,
                size: 28,
              ),

              const SizedBox(
                width: 14,
              ),

              // Informações da execução.
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    // Data.
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    // Horário.
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    // BPM.
                    Text(
                      'BPM: ${performance.bpm}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Pontuação.
              Text(
                '${performance.score.toStringAsFixed(0)}%',

                style: const TextStyle(
                  color:
                      Colors.deepPurpleAccent,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
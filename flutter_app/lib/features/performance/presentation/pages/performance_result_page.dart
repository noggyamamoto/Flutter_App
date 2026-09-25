import 'package:flutter/material.dart';

import '../widgets/music_history_widget.dart';
import '../widgets/performance_chart.dart';
import '../widgets/performance_score_card.dart';

class PerformanceResultPage
    extends StatefulWidget {
  final double precision;
  final int notesPlayed;

  const PerformanceResultPage({
    super.key,
    required this.precision,
    required this.notesPlayed,
  });

  @override
  State<PerformanceResultPage>
      createState() =>
          _PerformanceResultPageState();
}

class _PerformanceResultPageState
    extends State<
        PerformanceResultPage> {
  int selectedTab = 0;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0F0E17),
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
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

              PerformanceScoreCard(
                precision:
                    widget.precision,
                notesPlayed:
                    widget.notesPlayed,
              ),

              const SizedBox(
                height: 24,
              ),

              _buildTabs(),

              const SizedBox(
                height: 20,
              ),

              if (selectedTab == 0)
                _buildHistory()
              else
                _buildEvolution(),

              const SizedBox(
                height: 30,
              ),

              SizedBox(
                width: double.infinity,
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

        const MusicHistoryWidget(),

        const SizedBox(
          height: 12,
        ),

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

  Widget _buildEvolution() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Evolução da precisão',
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

        const PerformanceChart(
          values: [
            45,
            50,
            52,
            58,
            61,
            65,
          ],
        ),
      ],
    );
  }
}

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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(
          width: 5,
        ),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
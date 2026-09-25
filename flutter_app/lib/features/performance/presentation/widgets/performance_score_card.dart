import 'package:flutter/material.dart';

class PerformanceScoreCard
    extends StatelessWidget {
  final double precision;
  final int notesPlayed;

  const PerformanceScoreCard({
    super.key,
    required this.precision,
    required this.notesPlayed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            const Color(0xFF1A1922),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment:
                  Alignment.center,
              children: [
                CircularProgressIndicator(
                  value:
                      (precision / 100)
                          .clamp(0, 1),
                  strokeWidth: 10,
                  backgroundColor:
                      Colors.white12,
                ),

                Text(
                  '${precision.toInt()}%',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 24,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Precisão',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '$notesPlayed notas tocadas',
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
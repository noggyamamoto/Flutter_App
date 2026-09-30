import 'package:flutter/material.dart';

import '../../domain/entities/score_result.dart';

// Pontuação macro: precisão de altura (Hz) e de duração/tempo (RU13).
class ScoreResultWidget extends StatelessWidget {
  final ScoreResult result;

  const ScoreResultWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1922),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bar(
            label: 'Altura (notas certas)',
            value: result.pitchAccuracy,
            color: Colors.green,
          ),
          const SizedBox(height: 14),
          _Bar(
            label: 'Ritmo (tempo e duração)',
            value: result.rhythmAccuracy,
            color: const Color(0xFF9B6DDA),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Info(icon: Icons.check_circle_outline, text: '${result.notesCorrect} de ${result.notesExpected} corretas'),
              _Info(icon: Icons.add_circle_outline, text: '${result.extraNotes} extras'),
              _Info(
                icon: result.completed ? Icons.flag : Icons.pause_circle_outline,
                text: result.completed ? 'Música concluída' : 'Execução interrompida',
              ),
            ],
          ),
          if (result.phrases.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Por trecho',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final phrase in result.phrases)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _phraseColor(phrase.score).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _phraseColor(phrase.score).withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '${phrase.phraseIndex + 1}: ${phrase.score.round()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _phraseColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Bar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            Text(
              '${value.round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.white12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

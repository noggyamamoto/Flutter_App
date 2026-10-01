import 'package:flutter/material.dart';

import '../../../score/domain/entities/note_comparison.dart';
import '../../../score/domain/services/score_analyzer.dart';
import 'feedback_colors.dart';
import 'score_display.dart';

// Notas executadas na última performance, coloridas sobre a partitura.
class MusicHistoryWidget
    extends StatelessWidget {

  // Partitura e melodia avaliada.
  final ScoreStructure? structure;

  // Resultado de cada nota (id -> feedback).
  final Map<int, NoteFeedback> feedback;

  const MusicHistoryWidget({
    super.key,
    this.structure,
    this.feedback = const {},
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final structure = this.structure;

    return Container(
      height: 300,
      width: double.infinity,
      padding:
          const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: structure == null
          ? const Center(
              child: Text(
                'Nenhuma nota executada.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ScoreDisplay(
              score: structure.score,
              // Somente os compassos das frases tocadas.
              measureIndexes: _playedMeasures(structure),
              noteColors: FeedbackColors.map(feedback),
              zoom: 1.0,
            ),
    );
  }

  List<int> _playedMeasures(ScoreStructure structure) {
    final phrases = <int>{
      for (final note in structure.expectedNotes)
        if (note.scoreNoteIds.any(feedback.containsKey)) note.phraseIndex,
    };
    if (phrases.isEmpty) return structure.phrases.first.measureIndexes;
    return [
      for (final phrase in structure.phrases)
        if (phrases.contains(phrase.index)) ...phrase.measureIndexes,
    ];
  }
}

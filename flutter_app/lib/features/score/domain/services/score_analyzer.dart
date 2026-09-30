import '../entities/expected_note.dart';
import '../entities/musical_score.dart';
import '../entities/phrase.dart';

// Estrutura derivada de uma partitura para a execução:
// frases musicais (RFA07) e a melodia que será avaliada.
class ScoreStructure {
  final MusicalScore score;
  final List<Phrase> phrases;
  final List<ExpectedNote> expectedNotes;

  // IDs das notas da partitura que são avaliadas.
  final Set<int> evaluatedNoteIds;

  const ScoreStructure({
    required this.score,
    required this.phrases,
    required this.expectedNotes,
    required this.evaluatedNoteIds,
  });

  List<ExpectedNote> notesOfPhrase(int phraseIndex) =>
      expectedNotes.where((n) => n.phraseIndex == phraseIndex).toList();
}

class ScoreAnalyzer {
  // Agrupa os compassos em frases e extrai a melodia a ser avaliada.
  ScoreStructure analyze(
    MusicalScore score, {
    int measuresPerPhrase = 4,
  }) {
    final phrases = buildPhrases(score, measuresPerPhrase: measuresPerPhrase);
    final expected = extractMelody(score, phrases);

    return ScoreStructure(
      score: score,
      phrases: phrases,
      expectedNotes: expected,
      evaluatedNoteIds: {
        for (final note in expected) ...note.scoreNoteIds,
      },
    );
  }

  List<Phrase> buildPhrases(
    MusicalScore score, {
    int measuresPerPhrase = 4,
  }) {
    final perPhrase = measuresPerPhrase < 1 ? 1 : measuresPerPhrase;
    final measures = score.measures;
    final phrases = <Phrase>[];

    // Uma anacruse (compasso inicial incompleto) é somada à primeira frase.
    var first = 0;
    final hasPickup = measures.length > 1 &&
        measures.first.durationBeats < score.barBeats - 1e-6;

    while (first < measures.length) {
      var last = first + perPhrase - 1;
      if (phrases.isEmpty && hasPickup) last++;
      if (last >= measures.length) last = measures.length - 1;

      // Evita uma última frase com um único compasso.
      if (perPhrase > 1 && measures.length - 1 - last == 1) last++;

      phrases.add(
        Phrase(
          index: phrases.length,
          firstMeasure: first,
          lastMeasure: last,
          startBeat: measures[first].startBeat,
          endBeat: measures[last].endBeat,
        ),
      );
      first = last + 1;
    }

    return phrases;
  }

  // Melodia: nota mais aguda de cada ataque da pauta superior.
  List<ExpectedNote> extractMelody(
    MusicalScore score,
    List<Phrase> phrases,
  ) {
    final melodyStaff = _melodyStaff(score);

    // Agrupa as notas da pauta da melodia pelo instante de ataque.
    final byOnset = <double, List<ScoreNote>>{};
    for (final note in score.notes) {
      if (note.isRest || note.staff != melodyStaff) continue;
      final key = (note.startBeat * 1000).roundToDouble() / 1000;
      byOnset.putIfAbsent(key, () => []).add(note);
    }

    final onsets = byOnset.keys.toList()..sort();
    final result = <_MutableExpected>[];

    for (final onset in onsets) {
      final group = byOnset[onset]!;
      group.sort((a, b) => b.midi.compareTo(a.midi));
      final top = group.first;

      // Continuação de ligadura: prolonga a nota anterior de mesma altura.
      if (top.tieStop && result.isNotEmpty) {
        final previous = result.last;
        final gap = (previous.startBeat + previous.durationBeats) - top.startBeat;
        if (previous.midi == top.midi && gap.abs() < 1e-3) {
          previous.durationBeats += top.durationBeats;
          previous.ids.add(top.id);
          continue;
        }
      }

      result.add(
        _MutableExpected(
          midi: top.midi,
          startBeat: top.startBeat,
          durationBeats: top.durationBeats,
          ids: [top.id],
        ),
      );
    }

    return [
      for (var i = 0; i < result.length; i++)
        ExpectedNote(
          index: i,
          scoreNoteIds: result[i].ids,
          midi: result[i].midi,
          startBeat: result[i].startBeat,
          durationBeats: result[i].durationBeats,
          phraseIndex: _phraseOf(phrases, result[i].startBeat),
        ),
    ];
  }

  int _melodyStaff(MusicalScore score) {
    // Normalmente a pauta 1 (clave de sol). Se ela estiver vazia, usa a
    // pauta com mais notas.
    final counts = <int, int>{};
    for (final note in score.notes) {
      if (!note.isRest) counts[note.staff] = (counts[note.staff] ?? 0) + 1;
    }
    if ((counts[1] ?? 0) > 0) return 1;
    if (counts.isEmpty) return 1;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int _phraseOf(List<Phrase> phrases, double beat) {
    for (final phrase in phrases) {
      if (beat >= phrase.startBeat - 1e-6 && beat < phrase.endBeat - 1e-6) {
        return phrase.index;
      }
    }
    return phrases.isEmpty ? 0 : phrases.last.index;
  }
}

class _MutableExpected {
  final int midi;
  final double startBeat;
  double durationBeats;
  final List<int> ids;

  _MutableExpected({
    required this.midi,
    required this.startBeat,
    required this.durationBeats,
    required this.ids,
  });
}

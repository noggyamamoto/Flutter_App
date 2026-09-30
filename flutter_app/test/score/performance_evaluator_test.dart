import 'package:flutter_app/features/performance/domain/services/performance_timeline.dart';
import 'package:flutter_app/features/score/domain/entities/expected_note.dart';
import 'package:flutter_app/features/score/domain/entities/note_comparison.dart';
import 'package:flutter_app/features/score/domain/entities/phrase.dart';
import 'package:flutter_app/features/score/domain/services/performance_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

// Escala de Dó com 8 semínimas em duas frases de 1 compasso (4/4).
List<ExpectedNote> _scale() {
  const midis = [60, 62, 64, 65, 67, 69, 71, 72];
  return [
    for (var i = 0; i < midis.length; i++)
      ExpectedNote(
        index: i,
        scoreNoteIds: [i],
        midi: midis[i],
        startBeat: i.toDouble(),
        durationBeats: 1,
        phraseIndex: i ~/ 4,
      ),
  ];
}

const _phrases = [
  Phrase(index: 0, firstMeasure: 0, lastMeasure: 0, startBeat: 0, endBeat: 4),
  Phrase(index: 1, firstMeasure: 1, lastMeasure: 1, startBeat: 4, endBeat: 8),
];

// 120 BPM (500 ms por tempo) com 2 compassos de contagem (4 s).
PerformanceEvaluator _evaluator(List<ExpectedNote> notes, PerformanceTimeline timeline) {
  final evaluator = PerformanceEvaluator(notes);
  for (final n in notes) {
    evaluator.setTiming(
      n.index,
      timeline.beatToMs(n.startBeat).round(),
      timeline.durationMs(n.startBeat, n.durationBeats).round(),
    );
  }
  return evaluator;
}

PerformanceTimeline _timeline({int bpm = 120}) => PerformanceTimeline(
      phrases: _phrases,
      startPhrase: 0,
      countInMs: 4000,
      initialBpm: bpm,
    );

void main() {
  group('PerformanceTimeline', () {
    test('converte semínimas em ms com contagem de entrada', () {
      final t = _timeline();
      expect(t.beatToMs(0), 4000);
      expect(t.beatToMs(4), 6000);
      expect(t.endMs, 8000);
      expect(t.phraseAt(3999), isNull);
      expect(t.phraseAt(5000), 0);
      expect(t.msToBeat(5250), closeTo(2.5, 1e-9));
    });

    test('reduz o BPM a partir de uma frase', () {
      final t = _timeline()..setBpmFrom(1, 60);
      expect(t.phraseStartMs(1), 6000);
      expect(t.beatToMs(5), 7000); // 1 tempo a 60 BPM = 1000 ms
      expect(t.endMs, 10000);
      expect(t.msToBeat(8000), closeTo(6, 1e-9));
    });

    test('repetição a partir da segunda frase', () {
      final t = PerformanceTimeline(
        phrases: _phrases,
        startPhrase: 1,
        countInMs: 4000,
        initialBpm: 120,
      );
      expect(t.beatToMs(4), 4000);
      expect(t.phraseAt(4100), 1);
    });
  });

  group('PerformanceEvaluator', () {
    test('execução perfeita = 100%', () {
      final notes = _scale();
      final timeline = _timeline();
      final e = _evaluator(notes, timeline);
      for (final n in notes) {
        final onset = timeline.beatToMs(n.startBeat).round();
        final c = e.onNoteOn(midi: n.midi, onsetMs: onset);
        expect(c!.feedback, NoteFeedback.correct);
        e.onNoteOff(midi: n.midi, durationMs: 480, timeMs: onset + 480);
      }
      e.advance(9000);
      final result = e.buildResult(phrases: [0, 1], completed: true);
      expect(result.overall, closeTo(100, 0.5));
      expect(result.pitchAccuracy, 100);
      expect(result.notesCorrect, 8);
      expect(e.evaluatePhrase(0).failed, isFalse);
      expect(e.evaluatePhrase(0).unstable, isFalse);
    });

    test('classifica nota errada, semitom, atraso e nota perdida', () {
      final notes = _scale();
      final e = _evaluator(notes, _timeline());

      // Nota errada (Sol no lugar de Dó)
      expect(e.onNoteOn(midi: 67, onsetMs: 4000)!.feedback, NoteFeedback.incorrect);
      // Um semitom acima (Ré# no lugar de Ré)
      expect(e.onNoteOn(midi: 63, onsetMs: 4500)!.feedback, NoteFeedback.approximate);
      // Altura certa, 220 ms atrasada
      final late = e.onNoteOn(midi: 64, onsetMs: 5220)!;
      expect(late.feedback, NoteFeedback.approximate);
      expect(late.onsetErrorMs, 220);
      // Fá não foi tocado
      final missed = e.advance(6000);
      expect(missed.map((c) => c.expected.midi), [65]);
      expect(missed.single.feedback, NoteFeedback.missed);

      final phrase = e.evaluatePhrase(0);
      expect(phrase.notesMissed, 1);
      expect(phrase.score, lessThan(50));
      expect(phrase.failed, isTrue);
    });

    test('correção logo após um erro substitui o resultado', () {
      final notes = _scale();
      final e = _evaluator(notes, _timeline());
      expect(e.onNoteOn(midi: 61, onsetMs: 3980)!.feedback, NoteFeedback.approximate);
      expect(e.onNoteOn(midi: 60, onsetMs: 4060)!.feedback, NoteFeedback.correct);
      expect(e.resultOf(0)!.playedMidi, 60);
      expect(e.evaluatePhrase(0).extraNotes, 1);
    });

    test('notas fora de qualquer janela contam como extras', () {
      final notes = _scale();
      final e = _evaluator(notes, _timeline());
      // Depois da última nota (7500 ms ± 250 ms): nenhuma correspondência.
      expect(e.onNoteOn(midi: 80, onsetMs: 8600), isNull);
      expect(e.evaluatePhrase(1).extraNotes, 1);
      expect(e.evaluatePhrase(0).extraNotes, 0);
    });

    test('frase aprovada com ritmo irregular é marcada como instável', () {
      final notes = _scale();
      final e = _evaluator(notes, _timeline());
      const errors = [-150, 140, -130, 150];
      for (var i = 0; i < 4; i++) {
        e.onNoteOn(midi: notes[i].midi, onsetMs: 4000 + i * 500 + errors[i]);
      }
      final phrase = e.evaluatePhrase(0);
      expect(phrase.pitchAccuracy, 100);
      expect(phrase.failed, isFalse);
      expect(phrase.unstable, isTrue);
    });

    test('repetir uma frase limpa somente os resultados dela', () {
      final notes = _scale();
      final e = _evaluator(notes, _timeline());
      e.onNoteOn(midi: 60, onsetMs: 4000);
      e.onNoteOn(midi: 67, onsetMs: 6000);
      e.resetFromPhrase(1);
      expect(e.resultOf(0), isNotNull);
      expect(e.resultOf(4), isNull);
    });
  });
}

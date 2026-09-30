import 'dart:math';

import '../entities/expected_note.dart';
import '../entities/note_comparison.dart';
import '../entities/score_result.dart';

// Tolerâncias da avaliação.
class EvaluationTolerance {
  // Erro de ataque considerado perfeito (quantização + latência de rede).
  final int perfectOnsetMs;

  // Janela mínima e máxima para associar uma nota tocada à esperada.
  final int minWindowMs;
  final int maxWindowMs;

  // Fração da duração da nota usada como janela.
  final double windowFraction;

  // Duração máxima considerada (o som do teclado decai naturalmente).
  final int maxDurationMs;

  const EvaluationTolerance({
    this.perfectOnsetMs = 70,
    this.minWindowMs = 160,
    this.maxWindowMs = 400,
    this.windowFraction = 0.5,
    this.maxDurationMs = 1500,
  });
}

// Compara em tempo real as notas tocadas (eventos do dispositivo) com o
// gabarito da partitura, nota a nota (RFA06), por frase (RFA07) e no total
// (RFA10 / RU13).
//
// Os tempos são medidos no relógio da sessão do dispositivo (ms).
class PerformanceEvaluator {
  final List<ExpectedNote> notes;
  final EvaluationTolerance tolerance;

  // Horário previsto de cada nota esperada (índice -> ms).
  final Map<int, int> _onsetMs = {};
  final Map<int, int> _durationMs = {};

  // Comparações já concluídas (índice -> resultado).
  final Map<int, NoteComparison> _results = {};

  // Notas extras (sem correspondência) por frase.
  final Map<int, int> _extras = {};

  // Total de notas tocadas.
  int _played = 0;

  PerformanceEvaluator(
    this.notes, {
    this.tolerance = const EvaluationTolerance(),
  });

  // ------------------------------------------------------------------------
  // Linha do tempo
  // ------------------------------------------------------------------------

  // Define o horário esperado de uma nota (recalculado a cada mudança de BPM).
  void setTiming(int index, int onsetMs, int durationMs) {
    _onsetMs[index] = onsetMs;
    _durationMs[index] = durationMs;
  }

  // Limpa resultados e horários a partir de uma frase (repetição de trecho).
  void resetFromPhrase(int phraseIndex) {
    for (final note in notes) {
      if (note.phraseIndex >= phraseIndex) {
        _results.remove(note.index);
        _onsetMs.remove(note.index);
        _durationMs.remove(note.index);
      }
    }
    _extras.removeWhere((phrase, _) => phrase >= phraseIndex);
  }

  int _window(int index) {
    final duration = _durationMs[index] ?? 500;
    return (duration * tolerance.windowFraction)
        .round()
        .clamp(tolerance.minWindowMs, tolerance.maxWindowMs);
  }

  // ------------------------------------------------------------------------
  // Eventos do dispositivo
  // ------------------------------------------------------------------------

  // Nota tocada. Retorna a comparação criada/atualizada ou null (nota extra).
  NoteComparison? onNoteOn({
    required int midi,
    required int onsetMs,
    double? frequency,
  }) {
    _played++;

    ExpectedNote? best;
    double bestCost = double.infinity;

    for (final note in notes) {
      final expectedOnset = _onsetMs[note.index];
      if (expectedOnset == null) continue;

      final dt = onsetMs - expectedOnset;
      final window = _window(note.index);
      if (dt.abs() > window) continue;

      final pitch = _pitchScore(midi, note.midi);
      final previous = _results[note.index];

      // Só substitui um resultado anterior se a nova nota for melhor
      // (ex.: tocou errado e corrigiu logo em seguida).
      if (previous != null &&
          (previous.feedback == NoteFeedback.missed ||
              previous.pitchScore >= pitch)) {
        continue;
      }

      // Custo: prioriza a altura correta, depois a proximidade no tempo.
      final cost = (1 - pitch) * 2 + dt.abs() / window;
      if (cost < bestCost) {
        bestCost = cost;
        best = note;
      }
    }

    if (best == null) {
      final phrase = _nearestPhrase(onsetMs);
      _extras[phrase] = (_extras[phrase] ?? 0) + 1;
      return null;
    }

    // Uma tentativa substituída conta como nota extra.
    if (_results.containsKey(best.index)) {
      _extras[best.phraseIndex] = (_extras[best.phraseIndex] ?? 0) + 1;
    }

    final comparison = _compare(
      best,
      playedMidi: midi,
      frequency: frequency,
      onsetError: onsetMs - _onsetMs[best.index]!,
      playedDuration: null,
    );
    _results[best.index] = comparison;
    return comparison;
  }

  // Nota solta: completa a medida de duração da última nota correspondente.
  NoteComparison? onNoteOff({
    required int midi,
    required int durationMs,
    required int timeMs,
  }) {
    NoteComparison? target;
    for (final comparison in _results.values) {
      if (comparison.playedMidi != midi || comparison.playedDurationMs != null) {
        continue;
      }
      final onset = _onsetMs[comparison.expected.index]! + comparison.onsetErrorMs!;
      if (onset > timeMs) continue;
      if (target == null ||
          onset > _onsetMs[target.expected.index]! + target.onsetErrorMs!) {
        target = comparison;
      }
    }
    if (target == null) return null;

    final updated = _compare(
      target.expected,
      playedMidi: target.playedMidi,
      frequency: target.playedFrequency,
      onsetError: target.onsetErrorMs,
      playedDuration: durationMs,
    );
    _results[target.expected.index] = updated;
    return updated;
  }

  // Marca como perdidas as notas cuja janela já passou.
  List<NoteComparison> advance(int nowMs) {
    final missed = <NoteComparison>[];
    for (final note in notes) {
      final onset = _onsetMs[note.index];
      if (onset == null || _results.containsKey(note.index)) continue;
      if (nowMs > onset + _window(note.index)) {
        final comparison = NoteComparison(
          expected: note,
          playedMidi: null,
          playedFrequency: null,
          onsetErrorMs: null,
          playedDurationMs: null,
          expectedDurationMs: _durationMs[note.index] ?? 0,
          pitchScore: 0,
          rhythmScore: 0,
          feedback: NoteFeedback.missed,
        );
        _results[note.index] = comparison;
        missed.add(comparison);
      }
    }
    return missed;
  }

  // ------------------------------------------------------------------------
  // Pontuação
  // ------------------------------------------------------------------------

  double _pitchScore(int played, int expected) {
    if (played == expected) return 1;
    final diff = (played - expected).abs();
    // Um semitom de diferença ou a nota certa em outra oitava.
    if (diff == 1 || (diff % 12 == 0 && diff <= 24)) return 0.5;
    return 0;
  }

  NoteComparison _compare(
    ExpectedNote note, {
    required int? playedMidi,
    required double? frequency,
    required int? onsetError,
    required int? playedDuration,
  }) {
    final expectedDuration = _durationMs[note.index] ?? 0;
    final pitch = playedMidi == null ? 0.0 : _pitchScore(playedMidi, note.midi);

    // Ritmo: erro de ataque (peso maior) e duração, quando medida.
    final window = _window(note.index);
    final error = (onsetError ?? window).abs();
    final onsetScore = error <= tolerance.perfectOnsetMs
        ? 1.0
        : (1 - (error - tolerance.perfectOnsetMs) / (window - tolerance.perfectOnsetMs))
            .clamp(0.0, 1.0);

    var rhythm = onsetScore;
    if (playedDuration != null && expectedDuration > 0) {
      final expected = min(expectedDuration, tolerance.maxDurationMs);
      final played = min(playedDuration, tolerance.maxDurationMs);
      final ratio = max(played, 1) / expected;
      final durationScore = (1 - (log(ratio) / ln2).abs() / 1.5).clamp(0.0, 1.0);
      rhythm = onsetScore * 0.75 + durationScore * 0.25;
    }

    final NoteFeedback feedback;
    if (pitch >= 1) {
      feedback = rhythm >= 0.6 ? NoteFeedback.correct : NoteFeedback.approximate;
    } else if (pitch > 0) {
      feedback = NoteFeedback.approximate;
    } else {
      feedback = NoteFeedback.incorrect;
    }

    return NoteComparison(
      expected: note,
      playedMidi: playedMidi,
      playedFrequency: frequency,
      onsetErrorMs: onsetError,
      playedDurationMs: playedDuration,
      expectedDurationMs: expectedDuration,
      pitchScore: pitch,
      rhythmScore: rhythm,
      feedback: feedback,
    );
  }

  int _nearestPhrase(int timeMs) {
    var best = 0;
    var bestDistance = 1 << 30;
    for (final note in notes) {
      final onset = _onsetMs[note.index];
      if (onset == null) continue;
      final distance = (onset - timeMs).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = note.phraseIndex;
      }
    }
    return best;
  }

  NoteComparison? resultOf(int expectedIndex) => _results[expectedIndex];

  List<NoteComparison> get comparisons {
    final list = _results.values.toList()
      ..sort((a, b) => a.expected.index.compareTo(b.expected.index));
    return list;
  }

  // Avaliação de uma frase ao seu término (RFA07 / RFA08 / RFA09).
  PhraseResult evaluatePhrase(int phraseIndex) {
    final phraseNotes = notes.where((n) => n.phraseIndex == phraseIndex).toList();
    final extras = _extras[phraseIndex] ?? 0;
    return _summarize(phraseIndex, phraseNotes, extras);
  }

  PhraseResult _summarize(int phraseIndex, List<ExpectedNote> phraseNotes, int extras) {
    if (phraseNotes.isEmpty) {
      return PhraseResult(
        phraseIndex: phraseIndex,
        pitchAccuracy: 100,
        rhythmAccuracy: 100,
        score: extras == 0 ? 100 : max(0, 100 - extras * 10).toDouble(),
        notesExpected: 0,
        notesCorrect: 0,
        notesMissed: 0,
        extraNotes: extras,
        timingDeviationMs: 0,
        unstable: false,
      );
    }

    var pitch = 0.0;
    var rhythm = 0.0;
    var correct = 0;
    var missed = 0;
    final errors = <int>[];

    for (final note in phraseNotes) {
      final result = _results[note.index];
      if (result == null || result.feedback == NoteFeedback.missed) {
        missed++;
        continue;
      }
      pitch += result.pitchScore;
      rhythm += result.rhythmScore;
      if (result.isHit) correct++;
      if (result.onsetErrorMs != null) errors.add(result.onsetErrorMs!);
    }

    final n = phraseNotes.length;
    final score = ((pitch + rhythm) / 2) / (n + extras * 0.5) * 100;

    // Desvio-padrão do erro de ataque.
    var deviation = 0.0;
    if (errors.length > 1) {
      final mean = errors.reduce((a, b) => a + b) / errors.length;
      final variance =
          errors.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b) / errors.length;
      deviation = sqrt(variance);
    }

    final rhythmAccuracy = rhythm / n * 100;
    final unstable = score >= 50 &&
        (rhythmAccuracy < 70 || deviation > 90 || missed / n > 0.2);

    return PhraseResult(
      phraseIndex: phraseIndex,
      pitchAccuracy: pitch / n * 100,
      rhythmAccuracy: rhythmAccuracy,
      score: score.clamp(0, 100).toDouble(),
      notesExpected: n,
      notesCorrect: correct,
      notesMissed: missed,
      extraNotes: extras,
      timingDeviationMs: deviation,
      unstable: unstable,
    );
  }

  // Pontuação macro das frases executadas (RU13).
  ScoreResult buildResult({
    required List<int> phrases,
    required bool completed,
  }) {
    final phraseResults = [for (final p in phrases) evaluatePhrase(p)];
    final considered = notes.where((n) => phrases.contains(n.phraseIndex)).toList();
    final n = considered.length;
    final extras = phrases.fold(0, (sum, p) => sum + (_extras[p] ?? 0));

    var pitch = 0.0;
    var rhythm = 0.0;
    var correct = 0;
    for (final note in considered) {
      final result = _results[note.index];
      if (result == null) continue;
      pitch += result.pitchScore;
      rhythm += result.rhythmScore;
      if (result.isHit) correct++;
    }

    return ScoreResult(
      pitchAccuracy: n == 0 ? 0 : pitch / n * 100,
      rhythmAccuracy: n == 0 ? 0 : rhythm / n * 100,
      overall: n == 0 ? 0 : (((pitch + rhythm) / 2) / (n + extras * 0.5) * 100).clamp(0, 100).toDouble(),
      notesExpected: n,
      notesCorrect: correct,
      notesPlayed: _played,
      extraNotes: extras,
      completed: completed,
      comparisons: comparisons.where((c) => phrases.contains(c.expected.phraseIndex)).toList(),
      phrases: phraseResults,
    );
  }
}

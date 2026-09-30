import '../../../score/domain/entities/phrase.dart';

// Converte posições da partitura (semínimas) em tempo da sessão (ms),
// permitindo andamentos diferentes por frase (RU12 / RFA09).
//
// A sessão começa (0 ms) no início da contagem de entrada. A música
// começa, a partir da frase `startPhrase`, após `countInMs`.
class PerformanceTimeline {
  final List<Phrase> phrases;
  final int startPhrase;
  final double countInMs;

  // Andamento (semínimas por minuto) de cada frase.
  final Map<int, int> _bpm;

  PerformanceTimeline({
    required this.phrases,
    required this.startPhrase,
    required this.countInMs,
    required int initialBpm,
  }) : _bpm = {
          for (final phrase in phrases) phrase.index: initialBpm,
        };

  int bpmOf(int phraseIndex) => _bpm[phraseIndex] ?? _bpm.values.first;

  // Altera o andamento desta frase em diante.
  void setBpmFrom(int phraseIndex, int bpm) {
    for (final phrase in phrases) {
      if (phrase.index >= phraseIndex) _bpm[phrase.index] = bpm;
    }
  }

  double _beatMs(int phraseIndex) => 60000 / bpmOf(phraseIndex);

  // Início de uma frase no relógio da sessão.
  double phraseStartMs(int phraseIndex) {
    var t = countInMs;
    for (var p = startPhrase; p < phraseIndex && p < phrases.length; p++) {
      t += phrases[p].durationBeats * _beatMs(p);
    }
    return t;
  }

  double phraseEndMs(int phraseIndex) =>
      phraseStartMs(phraseIndex) + phrases[phraseIndex].durationBeats * _beatMs(phraseIndex);

  // Frase que contém o instante (ou null antes do início / após o fim).
  int? phraseAt(double timeMs) {
    if (timeMs < countInMs) return null;
    for (var p = startPhrase; p < phrases.length; p++) {
      if (timeMs < phraseEndMs(p)) return p;
    }
    return null;
  }

  int _phraseOfBeat(double beat) {
    for (final phrase in phrases) {
      if (beat < phrase.endBeat - 1e-9) return phrase.index;
    }
    return phrases.last.index;
  }

  // Semínima -> ms.
  double beatToMs(double beat) {
    final p = _phraseOfBeat(beat);
    return phraseStartMs(p) + (beat - phrases[p].startBeat) * _beatMs(p);
  }

  // Duração (ms) de um trecho que começa em `beat`.
  double durationMs(double beat, double beats) => beats * _beatMs(_phraseOfBeat(beat));

  // ms -> semínima (posição do cursor).
  double? msToBeat(double timeMs) {
    final p = phraseAt(timeMs);
    if (p == null) return null;
    return phrases[p].startBeat + (timeMs - phraseStartMs(p)) / _beatMs(p);
  }

  // Fim da execução no relógio da sessão.
  double get endMs => phraseEndMs(phrases.length - 1);
}

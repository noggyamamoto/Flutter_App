import 'dart:math';

import '../../../score/domain/entities/phrase.dart';

// Converte posições da partitura (semínimas) em tempo da sessão (ms),
// permitindo andamentos diferentes por frase (RU12 / RFA09).
//
// A sessão começa (0 ms) no início da contagem de entrada. A música
// começa, a partir da frase `startPhrase`, após `countInMs`.
//
// Sincronismo com o dispositivo: o metrônomo do firmware bate na unidade
// de tempo do compasso (`beatType`: em 6/8 a colcheia) com um BPM inteiro.
// A duração das notas aqui é calculada a partir desse MESMO BPM inteiro
// (e não do BPM em semínimas), para que a linha do tempo do app e as
// batidas que o aluno ouve não se afastem ao longo da música.
class PerformanceTimeline {
  final List<Phrase> phrases;
  final int startPhrase;
  final double countInMs;

  // Denominador da fórmula de compasso (unidade de tempo do metrônomo).
  final int beatType;

  // Andamento (semínimas por minuto) de cada frase.
  final Map<int, int> _bpm;

  PerformanceTimeline({
    required this.phrases,
    required this.startPhrase,
    required this.countInMs,
    required int initialBpm,
    this.beatType = 4,
  }) : _bpm = {
          for (final phrase in phrases) phrase.index: initialBpm,
        };

  // BPM inteiro do metrônomo do dispositivo para um andamento em semínimas.
  static int metronomeBpmFor(int quarterBpm, int beatType) =>
      max(20, (quarterBpm * beatType / 4).round());

  int bpmOf(int phraseIndex) => _bpm[phraseIndex] ?? _bpm.values.first;

  // BPM enviado ao metrônomo do dispositivo nesta frase.
  int metronomeBpmOf(int phraseIndex) => metronomeBpmFor(bpmOf(phraseIndex), beatType);

  // Batidas do metrônomo entre o início de `fromPhrase` e o de `toPhrase`.
  int metronomeBeatsBetween(int fromPhrase, int toPhrase) {
    var beats = 0.0;
    for (var p = fromPhrase; p < toPhrase && p < phrases.length; p++) {
      beats += phrases[p].durationBeats * beatType / 4;
    }
    return beats.round();
  }

  // Altera o andamento desta frase em diante.
  void setBpmFrom(int phraseIndex, int bpm) {
    for (final phrase in phrases) {
      if (phrase.index >= phraseIndex) _bpm[phrase.index] = bpm;
    }
    _starts = null;
  }

  // Batidas da contagem de entrada. A frase inicial nunca muda de andamento
  // (as mudanças valem a partir de frases seguintes).
  late final int countInBeats = (countInMs * metronomeBpmOf(startPhrase) / 60000).round();

  // Batida do metrônomo no instante (0 = primeira batida da contagem),
  // contada como o dispositivo conta: a contagem e, depois, as batidas de
  // cada frase no andamento dela. O tempo no compasso é
  // `metronomeBeatAt(t) % beatsPerBar + 1`, o mesmo do buzzer e do LED.
  int metronomeBeatAt(double timeMs) {
    if (timeMs <= 0) return 0;
    if (timeMs < countInMs) {
      return min(countInBeats - 1, (timeMs * metronomeBpmOf(startPhrase) / 60000).floor());
    }
    // Depois do fim o dispositivo continua batendo no andamento da última
    // frase até a sessão parar.
    final p = phraseAt(timeMs) ?? phrases.length - 1;
    final beatMs = 60000 / metronomeBpmOf(p);
    return countInBeats +
        metronomeBeatsBetween(startPhrase, p) +
        ((timeMs - phraseStartMs(p)) / beatMs).floor();
  }

  // Duração de uma semínima, derivada do BPM inteiro do metrônomo.
  double _beatMs(int phraseIndex) => 60000 / metronomeBpmOf(phraseIndex) * beatType / 4;

  // Início de cada frase (a partir de startPhrase) no relógio da sessão,
  // recalculado somente quando o andamento muda: estas consultas são feitas
  // a cada quadro da tela.
  List<double>? _starts;

  List<double> get _phraseStarts {
    final cached = _starts;
    if (cached != null) return cached;
    final starts = <double>[];
    var t = countInMs;
    for (var p = startPhrase; p <= phrases.length; p++) {
      starts.add(t);
      if (p < phrases.length) t += phrases[p].durationBeats * _beatMs(p);
    }
    return _starts = starts;
  }

  // Início de uma frase no relógio da sessão.
  double phraseStartMs(int phraseIndex) {
    if (phraseIndex <= startPhrase) return countInMs;
    final starts = _phraseStarts;
    return starts[min(phraseIndex, phrases.length) - startPhrase];
  }

  double phraseEndMs(int phraseIndex) =>
      phraseStartMs(phraseIndex) + phrases[phraseIndex].durationBeats * _beatMs(phraseIndex);

  // Frase que contém o instante (ou null antes do início / após o fim).
  int? phraseAt(double timeMs) {
    if (timeMs < countInMs) return null;
    final starts = _phraseStarts;
    for (var p = startPhrase; p < phrases.length; p++) {
      if (timeMs < starts[p + 1 - startPhrase]) return p;
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

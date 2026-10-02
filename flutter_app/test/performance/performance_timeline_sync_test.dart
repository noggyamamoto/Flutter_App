// A linha do tempo do app usa o mesmo BPM inteiro do metrônomo do firmware,
// inclusive em compassos cuja unidade de tempo não é a semínima.
import 'package:flutter_app/features/performance/domain/services/performance_timeline.dart';
import 'package:flutter_app/features/score/domain/entities/phrase.dart';
import 'package:flutter_test/flutter_test.dart';

// Duas frases de 4 compassos em 2/2 (cada compasso = 4 semínimas).
const _phrases = [
  Phrase(index: 0, firstMeasure: 0, lastMeasure: 3, startBeat: 0, endBeat: 16),
  Phrase(index: 1, firstMeasure: 4, lastMeasure: 7, startBeat: 16, endBeat: 32),
];

void main() {
  test('BPM do metrônomo na unidade de tempo do compasso', () {
    expect(PerformanceTimeline.metronomeBpmFor(100, 4), 100);
    expect(PerformanceTimeline.metronomeBpmFor(60, 8), 120);   // 6/8: colcheia
    expect(PerformanceTimeline.metronomeBpmFor(75, 2), 38);    // 2/2: 37,5 -> 38
  });

  test('2/2 a 75 BPM: notas seguem as batidas de 38 BPM do dispositivo', () {
    const beatType = 2;
    final metro = PerformanceTimeline.metronomeBpmFor(75, beatType);
    final halfNoteMs = 60000 / metro;                           // período do metrônomo
    final timeline = PerformanceTimeline(
      phrases: _phrases,
      startPhrase: 0,
      countInMs: 2 * 2 * halfNoteMs,                            // 2 compassos de 2 tempos
      initialBpm: 75,
      beatType: beatType,
    );
    // A 16ª semínima (= 8 mínimas) cai exatamente na 8ª batida após a contagem.
    expect(timeline.beatToMs(16), closeTo(timeline.countInMs + 8 * halfNoteMs, 1e-6));
    // Antes (BPM em semínimas) a diferença chegava a ~170 ms neste ponto.
    expect((timeline.beatToMs(16) - (timeline.countInMs + 16 * 60000 / 75)).abs(),
        greaterThan(150));
  });

  test('batida em que a frase começa (para o SET_TEMPO)', () {
    final timeline = PerformanceTimeline(
      phrases: _phrases,
      startPhrase: 0,
      countInMs: 0,
      initialBpm: 80,
      beatType: 2,
    );
    expect(timeline.metronomeBeatsBetween(0, 1), 8);           // 16 semínimas = 8 mínimas
    expect(timeline.metronomeBeatsBetween(0, 0), 0);
  });
}

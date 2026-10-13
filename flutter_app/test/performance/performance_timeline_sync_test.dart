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

  // Metrônomo visual calculado pelo relógio da sessão: mesma contagem do
  // dispositivo (contagem de entrada e, depois, as batidas de cada frase no
  // andamento dela), inclusive após uma mudança de andamento.
  test('batida do metrônomo no instante, como o dispositivo conta', () {
    const bpm = 120;                                           // 4/4: 500 ms por batida
    final timeline = PerformanceTimeline(
      phrases: _phrases,
      startPhrase: 0,
      countInMs: 8 * 500,                                      // 2 compassos de 4 tempos
      initialBpm: bpm,
    );
    timeline.setBpmFrom(1, 100);                               // frase 2: 600 ms por batida

    expect(timeline.countInBeats, 8);
    expect(timeline.metronomeBeatAt(0), 0);
    expect(timeline.metronomeBeatAt(499), 0);
    expect(timeline.metronomeBeatAt(500), 1);
    expect(timeline.metronomeBeatAt(3999), 7);                 // última da contagem
    expect(timeline.metronomeBeatAt(4000), 8);                 // 1º tempo da música
    expect(timeline.metronomeBeatAt(4000 + 16 * 500 - 1), 23);
    final phrase2 = timeline.phraseStartMs(1);
    expect(phrase2, 4000 + 16 * 500);
    expect(timeline.metronomeBeatAt(phrase2), 24);
    expect(timeline.metronomeBeatAt(phrase2 + 599), 24);
    expect(timeline.metronomeBeatAt(phrase2 + 600), 25);
    // Depois do fim o dispositivo continua batendo até a sessão parar.
    expect(timeline.metronomeBeatAt(timeline.endMs), 8 + 16 + 16);
    expect(timeline.metronomeBeatAt(timeline.endMs + 600), 8 + 16 + 17);
    // Início das frases recalculado com a mudança de andamento.
    expect(timeline.endMs, phrase2 + 16 * 600);
    expect(timeline.phraseAt(phrase2 - 1), 0);
    expect(timeline.phraseAt(phrase2), 1);
    expect(timeline.phraseAt(timeline.endMs), isNull);
  });
}

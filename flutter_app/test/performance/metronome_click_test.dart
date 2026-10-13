// Metrônomo sonoro do app: com o dispositivo conectado o clique é um estalo
// curto sem altura definida (o microfone não o confunde com uma nota).
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_app/features/performance/data/services/audio_synth.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _samples(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  return [for (var i = 44; i + 1 < wav.length; i += 2) data.getInt16(i, Endian.little) / 32768];
}

// Maior autocorrelação normalizada para períodos de C4 a C7 (como o YIN).
double _periodicity(List<double> x) {
  var best = 0.0;
  final energy = x.fold(0.0, (s, v) => s + v * v);
  if (energy == 0) return 0;
  for (var lag = AudioSynth.sampleRate ~/ 2100; lag <= AudioSynth.sampleRate ~/ 250; lag++) {
    var acc = 0.0;
    for (var i = 0; i + lag < x.length; i++) {
      acc += x[i] * x[i + lag];
    }
    best = max(best, acc / energy);
  }
  return best;
}

void main() {
  List<double> click(ClickSound sound) {
    final wav = AudioSynth.render(SynthRequest(
      notes: const [],
      clicks: const [SynthClick(timeMs: 0, accent: true)],
      totalMs: 40,
      clickSound: sound,
    ));
    return _samples(wav).take((0.03 * AudioSynth.sampleRate).round()).toList();
  }

  test('clique do dispositivo (estalo) é audível e sem altura definida', () {
    final wood = click(ClickSound.wood);
    final tone = click(ClickSound.tone);
    expect(wood.map((v) => v.abs()).reduce(max), greaterThan(0.1));
    expect(_periodicity(tone), greaterThan(0.5));      // Bipe: periódico (vira nota)
    expect(_periodicity(wood), lessThan(0.3));         // Estalo: aperiódico
  });
}

// Síntese da música guia e do metrônomo: a versão otimizada (osciladores
// por recorrência) gera o mesmo som da fórmula original e é rápida o
// bastante para não travar a interface na web (onde roda na thread da tela).
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_app/features/performance/data/services/audio_synth.dart';
import 'package:flutter_test/flutter_test.dart';

const _rate = AudioSynth.sampleRate;

// Fórmula original (sin/pow/exp por amostra).
void _referenceNote(List<double> mix, SynthNote note) {
  final f0 = 440.0 * pow(2, (note.midi - 69) / 12.0);
  final start = (note.startMs * _rate / 1000).round();
  final length = (note.durationMs * _rate / 1000).round();
  final release = (0.08 * _rate).round();
  final decay = 0.9 * pow(440 / f0, 0.35);
  final amp = 0.16 * note.velocity;
  for (var i = 0; i < length + release; i++) {
    final index = start + i;
    if (index < 0) continue;
    if (index >= mix.length) break;
    final t = i / _rate;
    var env = min(1.0, t / 0.004) * exp(-t / decay);
    if (i >= length) env *= 1 - (i - length) / release;
    var sample = 0.0;
    for (var k = 1; k <= 5; k++) {
      final fk = f0 * k;
      if (fk >= _rate / 2) break;
      sample += sin(2 * pi * fk * t) / pow(k, 1.3) * exp(-t * (k - 1) * 1.5);
    }
    mix[index] += amp * env * sample;
  }
}

List<double> _pcm(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  return [for (var i = 44; i + 1 < wav.length; i += 2) data.getInt16(i, Endian.little) / 32767];
}

double _softClip(double x) {
  if (x > 1) return 1;
  if (x < -1) return -1;
  return x - x * x * x / 3 * 0.5;
}

void main() {
  test('notas iguais às da fórmula original (graves, médias e agudas)', () {
    const notes = [
      SynthNote(midi: 21, startMs: 0, durationMs: 900),            // A0
      SynthNote(midi: 60, startMs: 300, durationMs: 1200, velocity: 0.55),
      SynthNote(midi: 96, startMs: 1500, durationMs: 400),          // C7
      SynthNote(midi: 108, startMs: 1900, durationMs: 300),         // C8: 2 harmônicos abaixo de Nyquist
    ];
    final wav = AudioSynth.render(const SynthRequest(notes: notes, clicks: [], totalMs: 2400));
    final got = _pcm(wav);

    final mix = List<double>.filled(got.length, 0);
    for (final note in notes) {
      _referenceNote(mix, note);
    }
    var worst = 0.0;
    for (var i = 0; i < got.length; i++) {
      worst = max(worst, (got[i] - _softClip(mix[i])).abs());
    }
    expect(worst, lessThan(1e-3));                                  // < 0,1% da escala
  });

  test('trecho de 8 s é gerado rapidamente', () {
    final request = SynthRequest(
      notes: [
        for (var i = 0; i < 32; i++) SynthNote(midi: 60 + i % 12, startMs: i * 250, durationMs: 240),
      ],
      clicks: [for (var i = 0; i < 32; i++) SynthClick(timeMs: i * 250, accent: i % 4 == 0)],
      totalMs: 8000,
      clickSound: ClickSound.wood,
    );
    AudioSynth.render(request);                                     // aquecimento
    final watch = Stopwatch()..start();
    AudioSynth.render(request);
    // Antes da otimização: ~100 ms neste teste.
    expect(watch.elapsedMilliseconds, lessThan(40));
  });

  test('síntese em etapas (web) gera o mesmo áudio', () async {
    final request = SynthRequest(
      notes: [
        for (var i = 0; i < 40; i++) SynthNote(midi: 48 + i % 24, startMs: i * 200, durationMs: 400),
      ],
      clicks: [for (var i = 0; i < 40; i++) SynthClick(timeMs: i * 200, accent: i % 3 == 0)],
      totalMs: 8000,
    );
    expect(await AudioSynth.renderInSteps(request), AudioSynth.render(request));
  });
}

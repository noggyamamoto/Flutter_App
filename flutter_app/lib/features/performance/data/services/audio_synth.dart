import 'dart:math';
import 'dart:typed_data';

// Nota a ser sintetizada.
class SynthNote {
  final int midi;
  final int startMs;
  final int durationMs;
  final double velocity;

  const SynthNote({
    required this.midi,
    required this.startMs,
    required this.durationMs,
    this.velocity = 0.8,
  });
}

// Clique de metrônomo.
class SynthClick {
  final int timeMs;
  final bool accent;

  const SynthClick({required this.timeMs, required this.accent});
}

// Parâmetros de uma renderização (enviados a um isolate).
class SynthRequest {
  final List<SynthNote> notes;
  final List<SynthClick> clicks;
  final int totalMs;

  const SynthRequest({
    required this.notes,
    required this.clicks,
    required this.totalMs,
  });
}

// Sintetizador simples de piano (aditivo) e metrônomo, gerando WAV PCM
// de 16 bits mono. Usado para a música guia (RU04) e para o metrônomo do
// modo demonstração, quando não há o buzzer do dispositivo.
class AudioSynth {
  static const int sampleRate = 22050;

  static Uint8List render(SynthRequest request) {
    final total = (request.totalMs * sampleRate / 1000).ceil() + sampleRate ~/ 4;
    final mix = Float32List(total);

    for (final note in request.notes) {
      _addNote(mix, note);
    }
    for (final click in request.clicks) {
      _addClick(mix, click);
    }
    return _toWav(mix);
  }

  static void _addNote(Float32List mix, SynthNote note) {
    final f0 = 440.0 * pow(2, (note.midi - 69) / 12.0);
    final start = (note.startMs * sampleRate / 1000).round();
    final length = (note.durationMs * sampleRate / 1000).round();
    final release = (0.08 * sampleRate).round();
    final decay = 0.9 * pow(440 / f0, 0.35);        // Notas graves soam por mais tempo
    final amp = 0.16 * note.velocity;

    for (var i = 0; i < length + release; i++) {
      final index = start + i;
      if (index < 0) continue;
      if (index >= mix.length) break;

      final t = i / sampleRate;
      var env = min(1.0, t / 0.004) * exp(-t / decay);
      if (i >= length) env *= 1 - (i - length) / release;

      var sample = 0.0;
      for (var k = 1; k <= 5; k++) {
        final fk = f0 * k;
        if (fk >= sampleRate / 2) break;
        sample += sin(2 * pi * fk * t) / pow(k, 1.3) * exp(-t * (k - 1) * 1.5);
      }
      mix[index] += amp * env * sample;
    }
  }

  static void _addClick(Float32List mix, SynthClick click) {
    final start = (click.timeMs * sampleRate / 1000).round();
    final f = click.accent ? 1760.0 : 880.0;
    final length = (0.03 * sampleRate).round();
    for (var i = 0; i < length; i++) {
      final index = start + i;
      if (index < 0 || index >= mix.length) continue;
      final t = i / sampleRate;
      mix[index] += 0.35 * exp(-t / 0.008) * sin(2 * pi * f * t);
    }
  }

  static Uint8List _toWav(Float32List mix) {
    final data = ByteData(44 + mix.length * 2);

    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + mix.length * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, mix.length * 2, Endian.little);

    for (var i = 0; i < mix.length; i++) {
      // Saturação suave para evitar distorção quando várias notas somam.
      final v = _softClip(mix[i]);
      data.setInt16(44 + i * 2, (v * 32767).round().clamp(-32768, 32767), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static double _softClip(double x) {
    if (x > 1) return 1;
    if (x < -1) return -1;
    return x - x * x * x / 3 * 0.5;
  }
}

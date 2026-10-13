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

// Timbre do clique do metrônomo.
enum ClickSound {
  // Bipe agudo (Lá 5 / Lá 6), igual ao buzzer do dispositivo. Usado no modo
  // demonstração, em que nenhum microfone ouve o app.
  tone,

  // Estalo curto sem altura definida (ruído), como um bloco de madeira. Com
  // o dispositivo conectado o microfone ouve o alto-falante: um clique sem
  // altura não é confundido com uma nota tocada.
  wood,
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
  final ClickSound clickSound;

  const SynthRequest({
    required this.notes,
    required this.clicks,
    required this.totalMs,
    this.clickSound = ClickSound.tone,
  });
}

// Sintetizador simples de piano (aditivo) e metrônomo, gerando WAV PCM
// de 16 bits mono. Usado para a música guia (RU04) e para o metrônomo do
// modo demonstração, quando não há o buzzer do dispositivo.
class AudioSynth {
  static const int sampleRate = 22050;

  static Uint8List render(SynthRequest request) {
    final mix = _mixFor(request);
    for (final note in request.notes) {
      _addNote(mix, note);
    }
    _addClicks(mix, request);
    final wav = _wavHeader(mix.length);
    _encode(mix, wav, 0, mix.length);
    return wav.buffer.asUint8List();
  }

  // Amostras sintetizadas entre duas pausas de renderInSteps (~5 ms de
  // processamento no navegador).
  static const _stepSamples = 40000;

  // Mesma síntese em etapas, devolvendo o controle ao laço de eventos entre
  // elas. Na web não há isolates: sem as pausas, gerar o áudio de um trecho
  // longo travaria a tela (cursor, metrônomo visual) por alguns quadros.
  static Future<Uint8List> renderInSteps(SynthRequest request) async {
    final mix = _mixFor(request);
    var work = 0;
    for (final note in request.notes) {
      work += _addNote(mix, note);
      if (work >= _stepSamples) {
        work = 0;
        await Future<void>.delayed(Duration.zero);
      }
    }
    _addClicks(mix, request);
    final wav = _wavHeader(mix.length);
    for (var from = 0; from < mix.length; from += _stepSamples * 2) {
      await Future<void>.delayed(Duration.zero);
      _encode(mix, wav, from, min(mix.length, from + _stepSamples * 2));
    }
    return wav.buffer.asUint8List();
  }

  static Float32List _mixFor(SynthRequest request) =>
      Float32List((request.totalMs * sampleRate / 1000).ceil() + sampleRate ~/ 4);

  static void _addClicks(Float32List mix, SynthRequest request) {
    for (final click in request.clicks) {
      if (request.clickSound == ClickSound.wood) {
        _addWoodClick(mix, click);
      } else {
        _addClick(mix, click);
      }
    }
  }

  // Harmônicos por nota.
  static const _harmonics = 5;

  // Piano aditivo: 5 harmônicos com amplitude 1/k^1,3 que decaem mais
  // rápido quanto mais agudos, envelope com ataque de 4 ms, decaimento
  // exponencial e soltura de 80 ms.
  //
  // Senos e exponenciais são gerados por recorrência (rotação de fase e
  // multiplicação por um fator constante), sem sin/pow/exp por amostra:
  // ~10x mais rápido. Na web a síntese roda na thread da interface, então
  // isso evita travamentos na troca de trecho. Devolve as amostras geradas.
  static int _addNote(Float32List mix, SynthNote note) {
    final f0 = 440.0 * pow(2, (note.midi - 69) / 12.0);
    final start = (note.startMs * sampleRate / 1000).round();
    final length = (note.durationMs * sampleRate / 1000).round();
    final release = (0.08 * sampleRate).round();
    final decay = 0.9 * pow(440 / f0, 0.35);        // Notas graves soam por mais tempo
    final amp = 0.16 * note.velocity;
    final attack = 0.004 * sampleRate;

    // Harmônicos abaixo da frequência de Nyquist (k * f0 < sampleRate / 2).
    // Estado de cada um: fase (cos, sen), passo de rotação e amplitude com
    // decaimento próprio.
    final count = max(0, min(_harmonics, (sampleRate / 2 / f0).ceil() - 1));
    final c = Float64List(count);
    final s = Float64List(count);
    final stepC = Float64List(count);
    final stepS = Float64List(count);
    final gain = Float64List(count);
    final fade = Float64List(count);
    for (var j = 0; j < count; j++) {
      final k = j + 1;
      final w = 2 * pi * f0 * k / sampleRate;
      c[j] = 1;
      s[j] = 0;
      stepC[j] = cos(w);
      stepS[j] = sin(w);
      gain[j] = 1 / pow(k, 1.3);
      fade[j] = exp(-(k - 1) * 1.5 / sampleRate);
    }
    final envFade = exp(-1 / (decay * sampleRate));

    var env = amp;                                   // amp * exp(-t / decay)
    final end = min(length + release, mix.length - start);
    for (var i = 0; i < end; i++) {
      var sample = 0.0;
      for (var j = 0; j < count; j++) {
        final cj = c[j];
        final sj = s[j];
        sample += sj * gain[j];
        c[j] = cj * stepC[j] - sj * stepS[j];
        s[j] = sj * stepC[j] + cj * stepS[j];
        gain[j] *= fade[j];
      }
      var e = env;
      if (i < attack) e *= i / attack;
      if (i >= length) e *= 1 - (i - length) / release;
      env *= envFade;

      final index = start + i;
      if (index >= 0) mix[index] += e * sample;
    }
    return max(0, end);
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

  // Estalo de ruído (12 ms) com decaimento rápido: sem periodicidade, o
  // detector de altura do dispositivo não o reconhece como nota.
  static void _addWoodClick(Float32List mix, SynthClick click) {
    final start = (click.timeMs * sampleRate / 1000).round();
    final length = (0.012 * sampleRate).round();
    final amp = click.accent ? 0.7 : 0.45;
    final random = Random(click.timeMs);          // Determinístico
    var previous = 0.0;
    for (var i = 0; i < length; i++) {
      final index = start + i;
      if (index < 0 || index >= mix.length) continue;
      final noise = random.nextDouble() * 2 - 1;
      // Diferença de primeira ordem: realça os agudos (estalo seco)
      final bright = noise - previous;
      previous = noise;
      final t = i / sampleRate;
      mix[index] += amp * exp(-t / 0.0025) * bright * 0.5;
    }
  }

  static ByteData _wavHeader(int samples) {
    final data = ByteData(44 + samples * 2);

    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + samples * 2, Endian.little);
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
    data.setUint32(40, samples * 2, Endian.little);
    return data;
  }

  // Converte as amostras [from, to) em PCM de 16 bits.
  static void _encode(Float32List mix, ByteData wav, int from, int to) {
    final pcm = Endian.host == Endian.little ? wav.buffer.asInt16List(44, mix.length) : null;
    for (var i = from; i < to; i++) {
      final x = mix[i];
      if (x == 0) continue;                          // Silêncio (a maior parte dos cliques)
      // Saturação suave para evitar distorção quando várias notas somam.
      final v = (_softClip(x) * 32767).round().clamp(-32768, 32767);
      if (pcm != null) {
        pcm[i] = v;
      } else {
        wav.setInt16(44 + i * 2, v, Endian.little);
      }
    }
  }

  static double _softClip(double x) {
    if (x > 1) return 1;
    if (x < -1) return -1;
    return x - x * x * x / 3 * 0.5;
  }
}

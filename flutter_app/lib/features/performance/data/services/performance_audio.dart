import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_synth.dart';

// Reprodução da música guia e dos cliques gerados pelo AudioSynth.
class PerformanceAudio {
  // Criado somente quando algum som for tocado.
  AudioPlayer? _instance;

  AudioPlayer get _player => _instance ??= AudioPlayer();

  bool _disposed = false;

  // Gera o áudio fora da thread da interface.
  Future<Uint8List> render(SynthRequest request) {
    return compute(AudioSynth.render, request);
  }

  Future<void> play(Uint8List wav) async {
    if (_disposed) return;
    try {
      await _player.stop();
      await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (e) {
      debugPrint('Falha ao reproduzir áudio: $e');
    }
  }

  Future<void> stop() async {
    if (_disposed || _instance == null) return;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _instance?.dispose();
    } catch (_) {}
  }
}

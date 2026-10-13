import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_synth.dart';
import 'wav_source.dart';

// Reprodução da música guia e dos cliques gerados pelo AudioSynth.
//
// Dois players se alternam: enquanto um toca (contagem de entrada ou o
// trecho atual), o outro já recebe o áudio do próximo trecho (preload).
// Na troca de trecho o próximo começa na hora, sem o tempo de preparação
// do player (decodificação e buffer), que atrasava e "engasgava" o
// metrônomo sonoro.
class PerformanceAudio {
  // Criados somente quando algum som for tocado.
  final List<AudioPlayer?> _players = [null, null];
  final List<Source?> _sources = [null, null];

  // Player que está tocando (ou tocou por último).
  int _active = 0;

  // Áudio carregado no outro player e a carga em andamento.
  Uint8List? _preloaded;
  Future<bool>? _preloading;

  bool _disposed = false;

  // Atraso a partir do qual o áudio começa adiantado (seek) para ficar
  // alinhado ao relógio da sessão.
  static const _seekThreshold = Duration(milliseconds: 25);

  AudioPlayer _player(int slot) {
    final existing = _players[slot];
    if (existing != null) return existing;
    final player = AudioPlayer();
    // Mantém o áudio carregado depois de tocar ou parar.
    player.setReleaseMode(ReleaseMode.stop).ignore();
    return _players[slot] = player;
  }

  // Gera o áudio sem travar a interface: em um isolate (celular e
  // computador) ou em etapas (web, onde não há isolates).
  Future<Uint8List> render(SynthRequest request) {
    if (kIsWeb) return AudioSynth.renderInSteps(request);
    return compute(AudioSynth.render, request);
  }

  // Carrega o áudio no player livre, sem tocar. O próximo play() com este
  // mesmo áudio começa imediatamente.
  Future<void> preload(Uint8List wav) async {
    if (_disposed) return;
    if (identical(wav, _preloaded)) {
      await _preloading;
      return;
    }
    _preloaded = wav;
    final loading = _load(1 - _active, wav);
    _preloading = loading;
    await loading;
  }

  // O áudio já está carregado (ou carregando) no player livre.
  bool isPreloaded(Uint8List wav) => identical(wav, _preloaded);

  Future<bool> _load(int slot, Uint8List wav) async {
    try {
      final player = _player(slot);
      await player.stop();
      final old = _sources[slot];
      final source = createWavSource(wav);
      _sources[slot] = source;
      await player.setSource(source);
      if (old != null) releaseWavSource(old);
      return true;
    } catch (e) {
      debugPrint('Falha ao carregar áudio: $e');
      return false;
    }
  }

  // `position`: começa a tocar a partir deste ponto do áudio (mantém o
  // metrônomo alinhado ao relógio da sessão quando o áudio começa depois
  // do instante em que deveria).
  Future<void> play(Uint8List wav, {Duration position = Duration.zero}) async {
    if (_disposed) return;
    try {
      if (identical(wav, _preloaded)) {
        // Troca de player antes de qualquer espera: uma nova pré-carga já
        // vai para o player que está saindo.
        final loading = _preloading;
        _preloaded = null;
        _preloading = null;
        final previous = _active;
        _active = 1 - previous;

        if (await loading == true) {
          final player = _player(_active);
          if (position > _seekThreshold) await player.seek(position);
          await player.resume();
          await _players[previous]?.stop();
          return;
        }
      }

      // Sem pré-carga: carrega e toca no player atual.
      final player = _player(_active);
      await player.stop();
      final old = _sources[_active];
      final source = createWavSource(wav);
      _sources[_active] = source;
      await player.play(source, position: position > Duration.zero ? position : null);
      if (old != null) releaseWavSource(old);
    } catch (e) {
      debugPrint('Falha ao reproduzir áudio: $e');
    }
  }

  // Posição do áudio que está tocando (null se nenhum player tocou ainda).
  Future<Duration?> position() async {
    final player = _players[_active];
    if (_disposed || player == null) return null;
    try {
      return await player.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  // Leva o áudio que está tocando para `position` (correção de alinhamento).
  Future<void> seek(Duration position) async {
    final player = _players[_active];
    if (_disposed || player == null) return;
    try {
      await player.seek(position);
    } catch (e) {
      debugPrint('Falha ao reposicionar áudio: $e');
    }
  }

  // Para o que está tocando. O áudio pré-carregado continua pronto (o
  // player livre não estava tocando).
  Future<void> stop() async {
    if (_disposed) return;
    for (final player in _players) {
      if (player == null) continue;
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (var slot = 0; slot < _players.length; slot++) {
      try {
        await _players[slot]?.dispose();
      } catch (_) {}
      final source = _sources[slot];
      if (source != null) releaseWavSource(source);
    }
  }
}

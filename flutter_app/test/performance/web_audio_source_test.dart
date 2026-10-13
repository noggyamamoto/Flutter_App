// Áudio no navegador: o WAV gerado vira um blob URL (sem data URI em base64)
// e é carregado pelo player do audioplayers.
//
//   flutter test --platform chrome test/performance/web_audio_source_test.dart
@TestOn('browser')
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_web/audioplayers_web.dart';
import 'package:audioplayers_web/global_audioplayers_web.dart';
import 'package:flutter_app/features/performance/data/services/audio_synth.dart';
import 'package:flutter_app/features/performance/data/services/wav_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AudioplayersPlatformInterface.instance = WebAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = WebGlobalAudioplayersPlatform();

  test('WAV gerado é carregado no player por blob URL', () async {
    final wav = await AudioSynth.renderInSteps(const SynthRequest(
      notes: [SynthNote(midi: 60, startMs: 0, durationMs: 500)],
      clicks: [SynthClick(timeMs: 0, accent: true)],
      totalMs: 1000,
    ));
    final source = createWavSource(wav);
    expect(source, isA<UrlSource>());
    expect((source as UrlSource).url, startsWith('blob:'));

    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(source);
    // 1 s de áudio + 250 ms de cauda.
    expect((await player.getDuration())!.inMilliseconds, closeTo(1250, 5));

    releaseWavSource(source);
    await player.dispose();
  });
}

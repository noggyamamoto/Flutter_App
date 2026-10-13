import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'wav_source_io.dart' if (dart.library.js_interop) 'wav_source_web.dart' as platform;

// Fonte de áudio para um WAV gerado em memória.
//
// Na web o audioplayers converte bytes em um data URI (base64 do arquivo
// inteiro, na thread da interface); aqui o WAV vira um blob URL, sem cópia
// nem codificação. Nas demais plataformas, os próprios bytes.
Source createWavSource(Uint8List wav) => platform.createWavSource(wav);

// Libera a fonte quando o player não a usa mais (blob URL na web).
void releaseWavSource(Source source) => platform.releaseWavSource(source);

import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

Source createWavSource(Uint8List wav) => BytesSource(wav, mimeType: 'audio/wav');

void releaseWavSource(Source source) {}

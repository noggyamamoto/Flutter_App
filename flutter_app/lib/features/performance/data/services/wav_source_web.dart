import 'dart:js_interop';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:web/web.dart' as web;

Source createWavSource(Uint8List wav) {
  final blob = web.Blob([wav.toJS].toJS, web.BlobPropertyBag(type: 'audio/wav'));
  return UrlSource(web.URL.createObjectURL(blob), mimeType: 'audio/wav');
}

void releaseWavSource(Source source) {
  if (source is UrlSource && source.url.startsWith('blob:')) {
    web.URL.revokeObjectURL(source.url);
  }
}

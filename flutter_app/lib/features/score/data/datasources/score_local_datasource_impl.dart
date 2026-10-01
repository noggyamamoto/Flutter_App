import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'score_local_datasource.dart';

class ScoreLocalDataSourceImpl implements ScoreLocalDataSource {
  final AssetBundle bundle;

  ScoreLocalDataSourceImpl({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  @override
  Future<String> getScoreFile(String path) async {
    final ByteData data;
    try {
      data = await bundle.load(path);
    } catch (_) {
      throw ScoreNotFoundException(path);
    }
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return decodeScore(bytes, path);
  }

  // Converte os bytes do arquivo em texto MusicXML.
  static String decodeScore(List<int> bytes, String path) {
    final compressed = path.toLowerCase().endsWith('.mxl') ||
        (bytes.length > 2 && bytes[0] == 0x50 && bytes[1] == 0x4B); // "PK" (zip)
    if (!compressed) return utf8.decode(bytes, allowMalformed: true);
    return _unzipMxl(bytes);
  }

  // MusicXML compactado (.mxl): o arquivo principal é indicado em
  // META-INF/container.xml (<rootfile full-path="...">).
  static String _unzipMxl(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String? rootPath;
    final container = archive.findFile('META-INF/container.xml');
    if (container != null) {
      final xml = XmlDocument.parse(utf8.decode(container.content as List<int>));
      rootPath = xml.findAllElements('rootfile').firstOrNull?.getAttribute('full-path');
    }
    final root = rootPath != null
        ? archive.findFile(rootPath)
        : archive.files.where((f) {
            final name = f.name.toLowerCase();
            return f.isFile &&
                !name.startsWith('meta-inf/') &&
                (name.endsWith('.xml') || name.endsWith('.musicxml'));
          }).firstOrNull;
    if (root == null) {
      throw const FormatException('Arquivo .mxl sem partitura MusicXML.');
    }
    return utf8.decode(root.content as List<int>, allowMalformed: true);
  }
}

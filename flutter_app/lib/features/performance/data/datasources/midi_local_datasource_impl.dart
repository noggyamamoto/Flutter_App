import 'package:flutter/services.dart';

import 'midi_local_datasource.dart';

class MidiLocalDataSourceImpl
    implements MidiLocalDataSource {
  @override
  Future<List<int>> getMidiFile(String path) async {
    final data = await rootBundle.load(path);

    return data.buffer.asUint8List();
  }
}
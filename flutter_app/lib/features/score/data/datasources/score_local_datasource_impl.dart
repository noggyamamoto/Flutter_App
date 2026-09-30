import 'package:flutter/services.dart';

import 'score_local_datasource.dart';

class ScoreLocalDataSourceImpl implements ScoreLocalDataSource {
  @override
  Future<String> getScoreFile(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      throw Exception('Partitura não encontrada: $path');
    }
  }
}

import 'package:flutter/foundation.dart';

import '../../domain/entities/musical_score.dart';
import '../../domain/repositories/score_repository.dart';
import '../../domain/services/musicxml_parser.dart';
import '../datasources/score_local_datasource.dart';

class ScoreRepositoryImpl implements ScoreRepository {
  // Pasta dos arquivos MusicXML (.musicxml, .xml, .mxl) dentro dos assets.
  static const basePath = 'assets/partituras';

  final ScoreLocalDataSource dataSource;
  final MusicXmlParser parser;

  // Partituras já interpretadas (a partitura é imutável): reabrir uma música
  // é instantâneo.
  final Map<String, Future<MusicalScore>> _cache = {};

  ScoreRepositoryImpl(this.dataSource, this.parser);

  @override
  Future<MusicalScore> getScore(String fileName) {
    final path = fileName.startsWith('assets/') ? fileName : '$basePath/$fileName';
    final cached = _cache[path];
    if (cached != null) return cached;
    final loading = _load(path);
    _cache[path] = loading;
    // Erros (arquivo inexistente, formato inválido) não ficam em cache.
    loading.then((_) {}, onError: (Object _) {
      _cache.remove(path);
    });
    return loading;
  }

  Future<MusicalScore> _load(String path) async {
    final text = await dataSource.getScoreFile(path);
    // Interpretar o MusicXML leva dezenas de milissegundos: fora da thread da
    // interface (a transição para a tela de execução não engasga). Na web
    // não há isolates.
    if (kIsWeb) return parser.parse(text);
    return compute(parser.parse, text);
  }
}

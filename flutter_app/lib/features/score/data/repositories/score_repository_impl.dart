import '../../domain/entities/musical_score.dart';
import '../../domain/repositories/score_repository.dart';
import '../../domain/services/musicxml_parser.dart';
import '../datasources/score_local_datasource.dart';

class ScoreRepositoryImpl implements ScoreRepository {
  // Pasta dos arquivos MusicXML (.musicxml, .xml, .mxl) dentro dos assets.
  static const basePath = 'assets/partituras';

  final ScoreLocalDataSource dataSource;
  final MusicXmlParser parser;

  ScoreRepositoryImpl(this.dataSource, this.parser);

  @override
  Future<MusicalScore> getScore(String fileName) async {
    final path = fileName.startsWith('assets/') ? fileName : '$basePath/$fileName';
    final text = await dataSource.getScoreFile(path);
    return parser.parse(text);
  }
}

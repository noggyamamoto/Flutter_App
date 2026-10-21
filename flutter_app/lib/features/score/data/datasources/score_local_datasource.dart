export '../../domain/repositories/score_repository.dart' show ScoreNotFoundException;

abstract class ScoreLocalDataSource {
  // Lê o conteúdo MusicXML de um arquivo .musicxml, .xml ou .mxl
  // (MusicXML compactado). Lança ScoreNotFoundException se não existir.
  Future<String> getScoreFile(String path);
}

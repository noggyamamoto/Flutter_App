abstract class ScoreLocalDataSource {
  // Lê o conteúdo de um arquivo MusicXML.
  Future<String> getScoreFile(String path);
}

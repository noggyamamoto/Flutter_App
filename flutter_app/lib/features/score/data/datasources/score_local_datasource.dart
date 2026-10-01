// Arquivo de partitura inexistente nos assets.
class ScoreNotFoundException implements Exception {
  final String path;

  const ScoreNotFoundException(this.path);

  @override
  String toString() => 'Partitura não encontrada: $path';
}

abstract class ScoreLocalDataSource {
  // Lê o conteúdo MusicXML de um arquivo .musicxml, .xml ou .mxl
  // (MusicXML compactado). Lança ScoreNotFoundException se não existir.
  Future<String> getScoreFile(String path);
}

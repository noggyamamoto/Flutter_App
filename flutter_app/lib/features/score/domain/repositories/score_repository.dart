import '../entities/musical_score.dart';

// Arquivo de partitura inexistente nos assets.
class ScoreNotFoundException implements Exception {
  final String path;

  const ScoreNotFoundException(this.path);

  @override
  String toString() => 'Partitura não encontrada: $path';
}

abstract class ScoreRepository {
  // Carrega e interpreta a partitura MusicXML.
  Future<MusicalScore> getScore(String fileName);
}

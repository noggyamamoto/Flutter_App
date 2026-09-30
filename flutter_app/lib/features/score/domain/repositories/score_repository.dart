import '../entities/musical_score.dart';

abstract class ScoreRepository {
  // Carrega e interpreta a partitura MusicXML.
  Future<MusicalScore> getScore(String fileName);
}

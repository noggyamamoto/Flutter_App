import '../entities/musical_score.dart';
import '../repositories/score_repository.dart';

class GetMusicScore {
  final ScoreRepository repository;

  GetMusicScore(this.repository);

  Future<MusicalScore> call(String fileName) {
    return repository.getScore(fileName);
  }
}

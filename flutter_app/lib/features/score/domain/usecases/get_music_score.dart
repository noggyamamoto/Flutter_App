import '../entities/musical_score.dart';
import '../repositories/score_repository.dart';

class GetMusicScore {
  final ScoreRepository repository;

  GetMusicScore(this.repository);

  Future<MusicalScore> call(String fileName) {
    return repository.getScore(fileName);
  }

  // Tenta cada arquivo na ordem (ex.: .musicxml, .xml, .mxl) e usa o
  // primeiro que existir. Erros de formato não são ignorados: se o arquivo
  // existe mas é inválido, o erro é informado.
  Future<MusicalScore> firstAvailable(List<String> fileNames) async {
    Object? lastError;
    for (final name in fileNames) {
      try {
        return await repository.getScore(name);
      } on FormatException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Nenhuma partitura informada.');
  }
}

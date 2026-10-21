import '../entities/musical_score.dart';
import '../repositories/score_repository.dart';

class GetMusicScore {
  final ScoreRepository repository;

  GetMusicScore(this.repository);

  Future<MusicalScore> call(String fileName) {
    return repository.getScore(fileName);
  }

  // Tenta cada arquivo na ordem (ex.: .musicxml, .xml, .mxl) e usa o
  // primeiro que existir. Só a falta do arquivo passa para o próximo: se o
  // arquivo existe mas não pôde ser interpretado, o erro é informado (e não
  // o "não encontrada" do último candidato).
  Future<MusicalScore> firstAvailable(List<String> fileNames) async {
    Object? lastError;
    for (final name in fileNames) {
      try {
        return await repository.getScore(name);
      } on ScoreNotFoundException catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Nenhuma partitura informada.');
  }
}

import '../repositories/songs_repository.dart';

class GetSongs {
  final SongsRepository repository;

  GetSongs(this.repository);

  Future<List<Map<String, dynamic>>> call() {
    return repository.getSongs();
  }
}
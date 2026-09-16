import 'package:flutter_app/features/songs/data/models/songs_model.dart';

import '../repositories/songs_repository.dart';

class GetSongs {
  final SongsRepository repository;

  GetSongs(this.repository);

  Future<List<SongsModel>> call() {
    return repository.getSongs();
  }
}
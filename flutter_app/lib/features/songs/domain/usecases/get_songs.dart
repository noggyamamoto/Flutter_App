import 'package:flutter_app/features/songs/domain/entities/song.dart';

import '../repositories/songs_repository.dart';

class GetSongs {
  final SongsRepository _repository;

  const GetSongs(this._repository);

  Future<List<Song>> call() async {
    return await _repository.getSongs();
  }
}
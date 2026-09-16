import 'package:flutter_app/features/songs/domain/entities/song.dart';

abstract class SongsRepository {
  Future<List<Song>> getSongs();
}
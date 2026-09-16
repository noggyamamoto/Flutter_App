import 'package:flutter_app/features/songs/data/models/songs_model.dart';

abstract class SongsRemoteDataSource {
  Future<List<SongsModel>> getSongs();
}
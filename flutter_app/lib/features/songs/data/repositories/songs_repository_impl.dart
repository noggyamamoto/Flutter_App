import 'package:flutter_app/features/songs/data/datasources/songs_remote_datasource.dart';
import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_app/features/songs/domain/repositories/songs_repository.dart';

class SongsRepositoryImpl implements SongsRepository {
  final SongsRemoteDataSource _dataSource;

  const SongsRepositoryImpl(this._dataSource);

  @override
  Future<List<Song>> getSongs() async {
    final songsModel = await _dataSource.getSongs();
    return songsModel.map((model) => model.toEntity()).toList();
  }
}
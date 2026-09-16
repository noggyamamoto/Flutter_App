import 'package:flutter_app/features/songs/data/datasources/songs_remote_datasource.dart';
import 'package:flutter_app/features/songs/data/models/songs_model.dart';
import 'package:flutter_app/features/songs/domain/repositories/songs_repository.dart';

class SongsRepositoryImpl implements SongsRepository {
  final SongsRemoteDataSource dataSource;

  SongsRepositoryImpl(this.dataSource);

  @override
  Future<List<SongsModel>> getSongs() {
    return dataSource.getSongs();
  }
}
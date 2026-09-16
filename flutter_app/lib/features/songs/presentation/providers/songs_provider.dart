import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app/features/songs/data/datasources/songs_remote_datasource.dart';
import 'package:flutter_app/features/songs/data/datasources/songs_remote_datasource_impl.dart';
import 'package:flutter_app/features/songs/data/models/songs_model.dart';
import 'package:flutter_app/features/songs/data/repositories/songs_repository_impl.dart';
import 'package:flutter_app/features/songs/domain/repositories/songs_repository.dart';
import 'package:flutter_app/features/songs/domain/usecases/get_songs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final songsDataSourceProvider = Provider<SongsRemoteDataSource>((ref) {
  final firestore = ref.watch(firestoreProvider);

  return SongsRemoteDatasourceImpl(firestore);
});

final songsRepositoryProvider = Provider<SongsRepository>((ref) {
  final dataSource = ref.watch(songsDataSourceProvider);

  return SongsRepositoryImpl(dataSource);
});

final getSongsProvider = Provider<GetSongs>((ref) {
  final repository = ref.watch(songsRepositoryProvider);

  return GetSongs(repository);
});

final songsProvider = FutureProvider<List<SongsModel>>((ref) {
  final getSongs = ref.watch(getSongsProvider);

  return getSongs();
});
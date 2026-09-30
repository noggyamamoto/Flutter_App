import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../songs/presentation/providers/songs_provider.dart';
import '../../data/datasources/trophy_remote_datasource.dart';
import '../../data/datasources/trophy_remote_datasource_impl.dart';
import '../../data/repositories/trophy_repository_impl.dart';
import '../../domain/entities/trophy_progress.dart';
import '../../domain/repositories/trophy_repository.dart';
import '../../domain/usecases/check_trophies.dart';
import '../../domain/usecases/get_trophies.dart';

// ---------------------------------------------------------
// DATASOURCE / REPOSITORY / USE CASES
// ---------------------------------------------------------

final trophyDataSourceProvider = Provider<TrophyRemoteDataSource>((ref) {
  return TrophyRemoteDataSourceImpl(FirebaseFirestore.instance);
});

final trophyRepositoryProvider = Provider<TrophyRepository>((ref) {
  return TrophyRepositoryImpl(ref.watch(trophyDataSourceProvider));
});

final getTrophiesProvider = Provider<GetTrophies>((ref) {
  return GetTrophies(ref.watch(trophyRepositoryProvider));
});

final checkTrophiesProvider = Provider<CheckTrophies>((ref) {
  return CheckTrophies(ref.watch(trophyRepositoryProvider));
});

// ---------------------------------------------------------
// MÚSICAS DE NÍVEL DIFÍCIL
// ---------------------------------------------------------

final hardSongIdsProvider = FutureProvider<Set<String>>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  return songs
      .where((s) => s.nivelDificuldade.toLowerCase() == 'difícil')
      .map((s) => s.id)
      .toSet();
});

// ---------------------------------------------------------
// TROFÉUS DO USUÁRIO
// ---------------------------------------------------------

final trophyProgressProvider =
    FutureProvider.family<List<TrophyProgress>, String>((ref, userId) async {
  final hardSongs = await ref.watch(hardSongIdsProvider.future);
  return ref.watch(getTrophiesProvider)(
    userId: userId,
    hardSongIds: hardSongs,
  );
});

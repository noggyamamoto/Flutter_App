import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/history_remote_datasource.dart';
import '../../data/datasources/history_remote_datasource_impl.dart';

import '../../data/repositories/history_repository_impl.dart';

import '../../domain/entities/performance_history.dart';

import '../../domain/repositories/history_repository.dart';

import '../../domain/usecases/get_performance_history.dart';
import '../../domain/usecases/save_performance.dart';


// ---------------------------------------------------------
// FIRESTORE
// ---------------------------------------------------------

final historyFirestoreProvider =
    Provider<FirebaseFirestore>((ref) {

  return FirebaseFirestore.instance;
});


// ---------------------------------------------------------
// DATASOURCE
// ---------------------------------------------------------

final historyDataSourceProvider =
    Provider<HistoryRemoteDataSource>((ref) {

  final firestore = ref.watch(
    historyFirestoreProvider,
  );

  return HistoryRemoteDataSourceImpl(
    firestore,
  );
});


// ---------------------------------------------------------
// REPOSITORY
// ---------------------------------------------------------

final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) {

  final dataSource = ref.watch(
    historyDataSourceProvider,
  );

  return HistoryRepositoryImpl(
    dataSource,
  );
});


// ---------------------------------------------------------
// USE CASE - BUSCAR HISTÓRICO
// ---------------------------------------------------------

final getPerformanceHistoryProvider =
    Provider<GetPerformanceHistory>((ref) {

  final repository = ref.watch(
    historyRepositoryProvider,
  );

  return GetPerformanceHistory(
    repository,
  );
});


// ---------------------------------------------------------
// USE CASE - SALVAR EXECUÇÃO
// ---------------------------------------------------------

final savePerformanceProvider =
    Provider<SavePerformance>((ref) {

  final repository = ref.watch(
    historyRepositoryProvider,
  );

  return SavePerformance(
    repository,
  );
});


// ---------------------------------------------------------
// PARÂMETROS DO HISTÓRICO
// ---------------------------------------------------------

class HistoryParams {

  final String userId;

  final String songId;

  const HistoryParams({
    required this.userId,
    required this.songId,
  });

  @override
  bool operator ==(Object other) {

    return other is HistoryParams &&
        other.userId == userId &&
        other.songId == songId;
  }

  @override
  int get hashCode {

    return Object.hash(
      userId,
      songId,
    );
  }
}


// ---------------------------------------------------------
// PROVIDER DO HISTÓRICO
// ---------------------------------------------------------

final historyProvider =
    FutureProvider.family<
        List<PerformanceHistory>,
        HistoryParams>((ref, params) {

  final getHistory = ref.watch(
    getPerformanceHistoryProvider,
  );

  return getHistory(
    userId: params.userId,
    songId: params.songId,
  );
});


// ---------------------------------------------------------
// MÚSICAS TOCADAS RECENTEMENTE
// ---------------------------------------------------------

final recentSongIdsProvider =
    FutureProvider.family<List<String>, String>((ref, userId) {

  final repository = ref.watch(
    historyRepositoryProvider,
  );

  return repository.getRecentSongIds(
    userId: userId,
    limit: 3,
  );
});

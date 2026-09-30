import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/score_local_datasource.dart';
import '../../data/datasources/score_local_datasource_impl.dart';
import '../../data/repositories/score_repository_impl.dart';
import '../../domain/repositories/score_repository.dart';
import '../../domain/services/musicxml_parser.dart';
import '../../domain/services/score_analyzer.dart';
import '../../domain/usecases/get_music_score.dart';

// ---------------------------------------------------------
// PARTITURA (MusicXML)
// ---------------------------------------------------------

final scoreDataSourceProvider = Provider<ScoreLocalDataSource>((ref) {
  return ScoreLocalDataSourceImpl();
});

final musicXmlParserProvider = Provider<MusicXmlParser>((ref) {
  return MusicXmlParser();
});

final scoreRepositoryProvider = Provider<ScoreRepository>((ref) {
  return ScoreRepositoryImpl(
    ref.watch(scoreDataSourceProvider),
    ref.watch(musicXmlParserProvider),
  );
});

final getMusicScoreProvider = Provider<GetMusicScore>((ref) {
  return GetMusicScore(ref.watch(scoreRepositoryProvider));
});

final scoreAnalyzerProvider = Provider<ScoreAnalyzer>((ref) {
  return ScoreAnalyzer();
});

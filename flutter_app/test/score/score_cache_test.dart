// Partituras interpretadas fora da thread da interface e guardadas em cache:
// reabrir uma música não lê nem interpreta o arquivo de novo.
import 'dart:io';

import 'package:flutter_app/features/score/data/datasources/score_local_datasource.dart';
import 'package:flutter_app/features/score/data/repositories/score_repository_impl.dart';
import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingDataSource implements ScoreLocalDataSource {
  int reads = 0;

  @override
  Future<String> getScoreFile(String path) async {
    reads++;
    final file = File(path);
    if (!file.existsSync()) throw ScoreNotFoundException(path);
    return file.readAsString();
  }
}

void main() {
  test('mesma partitura é lida e interpretada uma única vez', () async {
    final source = _CountingDataSource();
    final repository = ScoreRepositoryImpl(source, MusicXmlParser());

    final first = await repository.getScore('alecrim.musicxml');
    final second = await repository.getScore('alecrim.musicxml');

    expect(first.measures, isNotEmpty);
    expect(identical(first, second), isTrue);
    expect(source.reads, 1);
  });

  test('arquivo inexistente não fica em cache', () async {
    final source = _CountingDataSource();
    final repository = ScoreRepositoryImpl(source, MusicXmlParser());

    await expectLater(repository.getScore('nao_existe.xml'), throwsA(isA<ScoreNotFoundException>()));
    await expectLater(repository.getScore('nao_existe.xml'), throwsA(isA<ScoreNotFoundException>()));
    expect(source.reads, 2);
  });

  // A interpretação roda em outro isolate: o erro de formato chega igual
  // (GetMusicScore.firstAvailable depende do tipo FormatException).
  test('formato inválido continua sendo informado como FormatException', () async {
    final repository = ScoreRepositoryImpl(_TextDataSource('<score-partwise><part>'), MusicXmlParser());

    await expectLater(repository.getScore('quebrada.xml'), throwsA(isA<FormatException>()));
  });
}

class _TextDataSource implements ScoreLocalDataSource {
  final String text;

  _TextDataSource(this.text);

  @override
  Future<String> getScoreFile(String path) async => text;
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/features/connection/domain/entities/device.dart';
import 'package:flutter_app/features/connection/presentation/pages/connection_page.dart';
import 'package:flutter_app/features/connection/presentation/providers/connection_provider.dart';
import 'package:flutter_app/features/performance/domain/entities/performance_state.dart';
import 'package:flutter_app/features/performance/presentation/pages/performance_page.dart';
import 'package:flutter_app/features/performance/presentation/providers/performance_provider.dart';
import 'package:flutter_app/features/performance/presentation/widgets/score_display.dart';
import 'package:flutter_app/features/score/domain/entities/note_comparison.dart';
import 'package:flutter_app/features/score/domain/entities/score_result.dart';
import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_app/features/score/domain/services/score_analyzer.dart';
import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedPerformance extends PerformanceNotifier {
  final PerformanceState fixed;
  _FixedPerformance(this.fixed);

  int retries = 0;

  @override
  PerformanceState build() => fixed;

  @override
  Future<void> loadSong(Song song) async {}

  @override
  Future<void> retryPhrase({bool slower = false}) async => retries++;
}

class _FixedConnection extends ConnectionNotifier {
  final DeviceConnectionState fixed;
  _FixedConnection(this.fixed);

  final List<Device> connected = [];

  @override
  DeviceConnectionState build() => fixed;

  @override
  Future<void> search({String? address}) async {}

  @override
  Future<bool> connect(Device device) async {
    connected.add(device);
    return true;
  }
}

const _song = Song(
  id: 'alecrim',
  titulo: 'Alecrim',
  compositor: 'Folclore',
  nivelDificuldade: 'fácil',
  bpmPadrao: 100,
  arquivoMidi: 'alecrim.mid',
);

const _device = Device(
  id: '24:6F:28:AA:BB:CC',
  name: 'PartituraIoT-BBCC',
  address: '192.168.0.42',
  port: 54322,
  firmware: '1.0.0',
);

ScoreStructure _structure(String file) => ScoreAnalyzer().analyze(
      MusicXmlParser().parse(File('assets/partituras/$file').readAsStringSync()),
    );

Future<void> _pump(WidgetTester tester, Widget page, List overrides) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [...overrides],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a partitura é desenhada em todas as frases e larguras', (tester) async {
    for (final file in Directory('assets/partituras').listSync().whereType<File>()) {
      final structure = _structure(file.uri.pathSegments.last);
      for (final width in [320.0, 390.0, 800.0]) {
        for (final phrase in structure.phrases) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: width,
                  child: ScoreDisplay(
                    score: structure.score,
                    measureIndexes: phrase.measureIndexes,
                    cursorBeat: phrase.startBeat + 1,
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '${file.path} $width');
        }
      }
    }
  });

  testWidgets('tela de conexão lista e pareia o dispositivo', (tester) async {
    final notifier = _FixedConnection(
      const DeviceConnectionState(searched: true, devices: [_device]),
    );
    await _pump(tester, const ConnectionPage(), [
      connectionProvider.overrideWith(() => notifier),
    ]);

    expect(find.text('Nenhum dispositivo conectado'), findsOneWidget);
    expect(find.text('Usar modo demonstração'), findsOneWidget);

    await tester.tap(find.text('PartituraIoT-BBCC'));
    await tester.pump();
    expect(notifier.connected.single.id, _device.id);
  });

  testWidgets('execução mostra precisão e botão de parar', (tester) async {
    final structure = _structure('alecrim.xml');
    final first = structure.expectedNotes.first;
    await _pump(tester, const PerformancePage(song: _song), [
      connectionProvider.overrideWith(() => _FixedConnection(
            const DeviceConnectionState(status: DeviceConnectionStatus.connected, device: _device),
          )),
      performanceProvider.overrideWith(() => _FixedPerformance(PerformanceState(
            status: PerformanceStatus.running,
            structure: structure,
            bpm: 100,
            precision: 87,
            feedback: {for (final id in first.scoreNoteIds) id: NoteFeedback.correct},
            lastPlayedMidi: first.midi,
            lastFeedback: NoteFeedback.correct,
          ))),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('87%'), findsOneWidget);
    expect(find.text('PARAR'), findsOneWidget);
    expect(find.text('Trecho 1 de ${structure.phrases.length}'), findsOneWidget);
  });

  testWidgets('frase abaixo de 50% mostra a tela de incentivo', (tester) async {
    final notifier = _FixedPerformance(PerformanceState(
      status: PerformanceStatus.phraseFailed,
      structure: _structure('alecrim.xml'),
      bpm: 100,
      lastPhrase: const PhraseResult(
        phraseIndex: 1,
        pitchAccuracy: 40,
        rhythmAccuracy: 30,
        score: 35,
        notesExpected: 10,
        notesCorrect: 2,
        notesMissed: 4,
        extraNotes: 1,
        timingDeviationMs: 100,
        unstable: false,
      ),
    ));
    await _pump(tester, const PerformancePage(song: _song), [
      connectionProvider.overrideWith(() => _FixedConnection(
            const DeviceConnectionState(status: DeviceConnectionStatus.connected, device: _device),
          )),
      performanceProvider.overrideWith(() => notifier),
    ]);

    expect(find.text('Vamos praticar este trecho!'), findsOneWidget);
    await tester.tap(find.text('Repetir trecho'));
    await tester.pump();
    expect(notifier.retries, 1);
  });
}

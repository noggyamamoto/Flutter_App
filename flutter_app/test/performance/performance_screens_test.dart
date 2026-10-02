import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/features/connection/domain/entities/device.dart';
import 'package:flutter_app/features/connection/presentation/providers/connection_provider.dart';
import 'package:flutter_app/features/performance/domain/entities/performance_state.dart';
import 'package:flutter_app/features/performance/presentation/pages/performance_page.dart';
import 'package:flutter_app/features/performance/presentation/providers/performance_provider.dart';
import 'package:flutter_app/features/score/domain/entities/note_comparison.dart';
import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_app/features/score/domain/services/score_analyzer.dart';
import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Tela de execução em tamanhos de celular, tablet e navegador (RNFA01).
//
// Verifica que o layout não estoura em nenhum tamanho. Com a variável
// SCREENSHOT_DIR definida, salva capturas para conferência visual
// (as fontes do Flutter SDK são carregadas para o texto e os ícones):
//
//   SCREENSHOT_DIR=build/screens flutter test test/performance/performance_screens_test.dart
class _FixedPerformance extends PerformanceNotifier {
  final PerformanceState fixed;
  _FixedPerformance(this.fixed);

  @override
  PerformanceState build() => fixed;

  @override
  Future<void> loadSong(Song song) async {}
}

class _FixedConnection extends ConnectionNotifier {
  @override
  DeviceConnectionState build() => const DeviceConnectionState(
        status: DeviceConnectionStatus.connected,
        device: Device(
          id: 'demo',
          name: 'PartituraIoT-BBCC',
          address: '192.168.0.42',
          port: 54322,
          firmware: '1.0.0',
        ),
      );
}

const _song = Song(
  id: 'alecrim',
  titulo: 'Alecrim',
  compositor: 'Folclore',
  nivelDificuldade: 'fácil',
  bpmPadrao: 100,
  arquivoMidi: 'alecrim.mid',
);

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    any = true;
  }
  if (any) await loader.load();
}

PerformanceState _runningState() {
  final structure = ScoreAnalyzer().analyze(
    MusicXmlParser().parse(File('assets/partituras/alecrim.musicxml').readAsStringSync()),
  );
  final notes = structure.notesOfPhrase(0);
  final feedback = <int, NoteFeedback>{};
  final results = [
    NoteFeedback.correct,
    NoteFeedback.correct,
    NoteFeedback.approximate,
    NoteFeedback.correct,
    NoteFeedback.incorrect,
    NoteFeedback.correct,
  ];
  for (var i = 0; i < results.length && i < notes.length; i++) {
    for (final id in notes[i].scoreNoteIds) {
      feedback[id] = results[i];
    }
  }
  final last = notes[results.length - 1];
  return PerformanceState(
    status: PerformanceStatus.running,
    structure: structure,
    bpm: 100,
    initialBpm: 100,
    feedback: feedback,
    cursorBeat: notes[results.length].startBeat - 0.1,
    precision: 82,
    notesPlayed: results.length,
    streak: 1,
    bestStreak: 3,
    beatInBar: 2,
    elapsed: const Duration(seconds: 11),
    lastPlayedMidi: last.midi,
    lastFeedback: NoteFeedback.correct,
    phraseScores: const {},
    judgement: NoteJudgement(
      serial: 1,
      noteId: last.scoreNoteIds.first,
      feedback: NoteFeedback.correct,
      label: 'Perfeito!',
    ),
  );
}

void main() {
  final outDir = Platform.environment['SCREENSHOT_DIR'];
  const fonts = '/opt/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
  final sdkFonts = Platform.environment['FLUTTER_FONTS'] ?? fonts;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFont('Bravura', ['assets/fonts/Bravura.otf']);
    await _loadFont('Roboto', [
      '$sdkFonts/Roboto-Regular.ttf',
      '$sdkFonts/Roboto-Medium.ttf',
      '$sdkFonts/Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$sdkFonts/MaterialIcons-Regular.otf']);
  });

  final sizes = {
    'celular': const Size(390, 844),
    'celular_deitado': const Size(844, 390),
    'tablet': const Size(820, 1180),
    'web': const Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    for (final status in ['pronto', 'execucao', 'sugestao']) {
      testWidgets('tela de execução – ${entry.key} – $status', (tester) async {
        tester.view.physicalSize = entry.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        final running = _runningState();
        final state = switch (status) {
          'pronto' => PerformanceState(
              status: PerformanceStatus.ready,
              structure: running.structure,
              bpm: 100,
              initialBpm: 100,
            ),
          // Trecho instável com ajuste manual (RFA09): a sugestão fica nos
          // controles e nenhum aviso é desenhado sobre a partitura.
          'sugestao' => running.copyWith(
              bpm: 90,
              suggestedBpm: 81,
              message: 'aviso que não deve cobrir a partitura',
            ),
          _ => running,
        };

        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              performanceProvider.overrideWith(() => _FixedPerformance(state)),
              connectionProvider.overrideWith(() => _FixedConnection()),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.deepPurple),
                home: const PerformancePage(song: _song),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        if (status == 'sugestao') {
          expect(find.text('aviso que não deve cobrir a partitura'), findsNothing);
          expect(find.text('Reduzir para 81 BPM'), findsOneWidget);
        }

        if (outDir != null) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final out = File('$outDir/${entry.key}_$status.png')..createSync(recursive: true);
            out.writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      });
    }
  }
}

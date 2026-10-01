import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/features/performance/presentation/widgets/score_display.dart';
import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_app/features/score/domain/services/score_analyzer.dart';
import 'package:flutter_app/features/score/presentation/notation/score_engraver.dart';
import 'package:flutter_test/flutter_test.dart';

// Renderiza todas as partituras do repertório.
//
// Sempre verifica que nenhum elemento sai da área visível e que o desenho
// não gera exceções. Com a variável SCORE_RENDER_DIR definida, também salva
// as imagens PNG para conferência visual:
//
//   SCORE_RENDER_DIR=build/score_renders flutter test test/score/score_render_test.dart
Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

List<File> _scoreFiles() => Directory('assets/partituras')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.xml') || f.path.endsWith('.musicxml'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  final outDir = Platform.environment['SCORE_RENDER_DIR'];

  setUpAll(() async {
    await _loadFont('Bravura', 'assets/fonts/Bravura.otf');
    // Fonte de texto para os números (opcional nos testes).
    final roboto = Platform.environment['SCORE_TEXT_FONT'];
    if (roboto != null) await _loadFont('Roboto', roboto);
  });

  test('nenhum elemento sai da largura disponível', () {
    for (final file in _scoreFiles()) {
      final score = MusicXmlParser().parse(file.readAsStringSync());
      final structure = ScoreAnalyzer().analyze(score);
      for (final width in [300.0, 360.0, 390.0, 768.0, 1280.0]) {
        for (final phrase in structure.phrases) {
          final layout = ScoreEngraver(score).engrave(
            measureIndexes: phrase.measureIndexes,
            width: width,
            zoom: 1.2,
          );
          for (final system in layout.systems) {
            expect(system.startX, greaterThanOrEqualTo(0), reason: '${file.path} $width');
            expect(system.endX, lessThanOrEqualTo(width + 0.5), reason: '${file.path} $width');
            for (final item in system.items) {
              expect(item.minY, greaterThanOrEqualTo(system.top - 0.5),
                  reason: '${file.path} $width ${item.runtimeType}');
              expect(item.maxY, lessThanOrEqualTo(system.bottom + 0.5),
                  reason: '${file.path} $width ${item.runtimeType}');
            }
          }
          // Todas as notas da frase receberam posição.
          for (final m in phrase.measureIndexes) {
            for (final n in score.measures[m].notes.where((n) => !n.isRest)) {
              expect(layout.noteBounds.containsKey(n.id), isTrue, reason: '${file.path} nota ${n.id}');
            }
          }
        }
      }
    }
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('renderiza o repertório completo ($width px)', (tester) async {
      for (final file in _scoreFiles()) {
        final score = MusicXmlParser().parse(file.readAsStringSync());
        final key = GlobalKey();
        tester.view.physicalSize = Size(width * 2, 6000 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Material(
              color: Colors.white,
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    color: Colors.white,
                    width: width,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ScoreDisplay(
                      score: score,
                      measureIndexes: [for (var i = 0; i < score.measures.length; i++) i],
                      zoom: 1.0,
                      scrollable: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: file.path);

        if (outDir != null) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final name = file.uri.pathSegments.last.replaceAll('.', '_');
            final out = File('$outDir/${name}_${width.round()}.png')..createSync(recursive: true);
            out.writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
    });
  }
}

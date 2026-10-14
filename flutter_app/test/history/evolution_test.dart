// Aba Evolução e execuções anteriores: resumo, gráfico, lista e reabertura
// de uma execução com a mesma tela do fim da execução.
//
// Com a variável SCREENSHOT_DIR definida, salva capturas (modo escuro e
// claro) para conferência visual:
//
//   SCREENSHOT_DIR=build/screens flutter test test/history/evolution_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/domain/entities/app_user.dart';
import 'package:flutter_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_app/features/history/data/models/performance_history_model.dart';
import 'package:flutter_app/features/history/domain/entities/performance_history.dart';
import 'package:flutter_app/features/history/domain/services/evolution_stats.dart';
import 'package:flutter_app/features/history/presentation/pages/past_performance_page.dart';
import 'package:flutter_app/features/history/presentation/providers/history_provider.dart';
import 'package:flutter_app/features/history/presentation/widgets/evolution_panel.dart';
import 'package:flutter_app/features/performance/presentation/pages/performance_result_page.dart';
import 'package:flutter_app/features/performance/presentation/widgets/performance_chart.dart';
import 'package:flutter_app/features/score/domain/entities/musical_score.dart';
import 'package:flutter_app/features/score/domain/entities/note_comparison.dart';
import 'package:flutter_app/features/score/domain/entities/score_result.dart';
import 'package:flutter_app/features/score/domain/repositories/score_repository.dart';
import 'package:flutter_app/features/score/domain/services/musicxml_parser.dart';
import 'package:flutter_app/features/score/domain/services/score_analyzer.dart';
import 'package:flutter_app/features/score/domain/usecases/get_music_score.dart';
import 'package:flutter_app/features/score/presentation/providers/score_provider.dart';
import 'package:flutter_app/features/score/presentation/widgets/score_result_widget.dart';
import 'package:flutter_app/features/songs/domain/entities/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileScoreRepository implements ScoreRepository {
  @override
  Future<MusicalScore> getScore(String fileName) async {
    final file = File('assets/partituras/$fileName');
    if (!file.existsSync()) throw Exception('não encontrada: $fileName');
    return MusicXmlParser().parse(file.readAsStringSync());
  }
}

class _LoggedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: 'aluno', nome: 'Ana', email: 'ana@exemplo.com'),
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

final _now = DateTime(2026, 10, 14, 18);

ScoreStructure _structure() => ScoreAnalyzer().analyze(
      MusicXmlParser().parse(File('assets/partituras/alecrim.musicxml').readAsStringSync()),
    );

// Resultado nota a nota do primeiro trecho (como salvo no Firestore).
Map<int, NoteFeedback> _phraseFeedback(ScoreStructure structure) {
  const pattern = [
    NoteFeedback.correct,
    NoteFeedback.correct,
    NoteFeedback.approximate,
    NoteFeedback.incorrect,
    NoteFeedback.missed,
  ];
  final feedback = <int, NoteFeedback>{};
  final notes = structure.notesOfPhrase(0);
  for (var i = 0; i < notes.length; i++) {
    for (final id in notes[i].scoreNoteIds) {
      feedback[id] = pattern[i % pattern.length];
    }
  }
  return feedback;
}

const _phrase = PhraseResult(
  phraseIndex: 0,
  pitchAccuracy: 72,
  rhythmAccuracy: 64,
  score: 68,
  notesExpected: 15,
  notesCorrect: 9,
  notesMissed: 3,
  extraNotes: 1,
  timingDeviationMs: 48.5,
  unstable: true,
);

// `count` execuções, uma por dia, da mais antiga para a mais recente.
// A 3ª tem o resultado nota a nota; as duas primeiras são antigas (sem
// altura/ritmo nem notas).
List<PerformanceHistory> _history(int count, ScoreStructure structure) {
  final scores = [42, 55, 61, 58, 66, 70, 68, 75, 81, 79, 86, 90, 88, 93];
  return [
    for (var i = 0; i < count; i++)
      PerformanceHistory(
        executionId: 'exec$i',
        songId: 'alecrim',
        date: _now.subtract(Duration(days: count - 1 - i, hours: 2)),
        score: scores[i % scores.length].toDouble(),
        bpm: 80 + i * 2,
        finalBpm: i == 5 ? 80 : null,
        status: i == 1 || i == 5 ? 'interrompida' : 'concluida',
        pitchScore: i < 2 ? null : scores[i % scores.length] + 4.0,
        rhythmScore: i < 2 ? null : scores[i % scores.length] - 6.0,
        notesPlayed: i < 2 ? null : 40 + i,
        notesCorrect: i < 2 ? null : 30 + i,
        notesExpected: i < 2 ? null : 60,
        extraNotes: i < 2 ? null : 2,
        bestStreak: i < 2 ? null : 7 + i,
        measuresPerPhrase: 4,
        phrases: i == 2 ? const [_phrase] : const [],
        noteFeedback: i == 2 ? _phraseFeedback(structure) : const {},
      ),
  ].reversed.toList(); // mais recentes primeiro, como o repositório
}

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

ThemeData _theme(bool light) {
  final base = light ? AppTheme.light : AppTheme.dark;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
  );
}

Future<void> _pumpResult(
  WidgetTester tester,
  List<PerformanceHistory> history, {
  bool light = false,
  Size size = const Size(390, 844),
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final latest = history.first;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_LoggedIn.new),
        historyProvider.overrideWith((ref, params) async => history),
        getMusicScoreProvider.overrideWithValue(GetMusicScore(_FileScoreRepository())),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _theme(light),
          home: PerformanceResultPage(
            song: _song,
            precision: latest.score,
            notesPlayed: latest.notesPlayed,
            result: latest.scoreResult,
            bestStreak: latest.bestStreak,
            executionId: latest.executionId,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _screenshot(WidgetTester tester, GlobalKey key, String name) async {
  final outDir = Platform.environment['SCREENSHOT_DIR'];
  if (outDir == null) return;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('$outDir/$name.png')..createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// Rola a página até o widget e o deixa visível.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  late ScoreStructure structure;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    structure = _structure();
    const fonts = '/opt/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
    final sdkFonts = Platform.environment['FLUTTER_FONTS'] ?? fonts;
    await _loadFont('Bravura', ['assets/fonts/Bravura.otf']);
    await _loadFont('Roboto', [
      '$sdkFonts/Roboto-Regular.ttf',
      '$sdkFonts/Roboto-Medium.ttf',
      '$sdkFonts/Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$sdkFonts/MaterialIcons-Regular.otf']);
  });

  group('dados salvos da execução', () {
    test('trechos e resultado de cada nota vão e voltam do Firestore', () {
      final feedback = {
        12: NoteFeedback.correct,
        13: NoteFeedback.approximate,
        14: NoteFeedback.missed,
        15: NoteFeedback.pending,
      };
      final model = PerformanceHistoryModel.fromMap({
        'executionId': 'x',
        'idPartitura': 'alecrim',
        'pontuacaoFinal': 68.4,
        'bpmInicial': 100,
        'bpmFinal': 90,
        'status': 'concluida',
        'pontuacaoAltura': 72,
        'pontuacaoRitmo': 64,
        'notasTocadas': 15,
        'notasCorretas': 9,
        'notasEsperadas': 15,
        'notasExtras': 1,
        'maiorSequencia': 5,
        'compassosPorTrecho': 2,
        'trechos': [PerformanceHistoryModel.phraseToMap(_phrase)],
        'resultadoNotas': PerformanceHistoryModel.feedbackToMap(feedback),
      });
      final entity = model.toEntity();

      // Pendente não é salva.
      expect(entity.noteFeedback, {
        12: NoteFeedback.correct,
        13: NoteFeedback.approximate,
        14: NoteFeedback.missed,
      });
      expect(entity.bestStreak, 5);
      expect(entity.measuresPerPhrase, 2);
      expect(entity.completed, isTrue);
      final phrase = entity.phrases.single;
      expect(phrase.score, 68);
      expect(phrase.notesMissed, 3);
      expect(phrase.timingDeviationMs, 48.5);
      expect(phrase.unstable, isTrue);

      final result = entity.scoreResult!;
      expect(result.overall, 68.4);
      expect(result.pitchAccuracy, 72);
      expect(result.notesExpected, 15);
      expect(result.extraNotes, 1);
      expect(result.phrases.single.phraseIndex, 0);
    });

    test('execução antiga (sem detalhes) continua legível', () {
      final entity = PerformanceHistoryModel.fromMap({
        'executionId': 'antiga',
        'idPartitura': 'alecrim',
        'pontuacaoFinal': 50,
        'bpmInicial': 90,
        'status': 'interrompida',
      }).toEntity();
      expect(entity.hasNoteDetails, isFalse);
      expect(entity.phrases, isEmpty);
      expect(entity.scoreResult, isNull);
    });
  });

  group('resumo da evolução', () {
    test('melhor, médias, tendência, número da execução e andamento', () {
      final history = _history(12, structure);
      final stats = EvolutionStats.from(history);

      expect(stats.count, 12);
      expect(stats.completedCount, 10);
      expect(stats.best!.score, 90);
      expect(stats.latest!.executionId, 'exec11');
      expect(stats.chronological.first.executionId, 'exec0');
      expect(stats.ordinalOf('exec2'), 3);
      expect(stats.previousOf(history.first)!.executionId, 'exec10');

      // Últimas 5 (90, 86, 79, 81, 75) contra as 5 anteriores (68, 70, 66, 58, 61).
      expect(stats.averageWindow, 5);
      expect(stats.recentAverage, closeTo(82.2, 0.01));
      expect(stats.previousAverage, closeTo(64.6, 0.01));
      expect(stats.trend, EvolutionTrend.improving);

      // Maior BPM de música concluída (a 6ª foi interrompida).
      expect(stats.maxBpm, 102);
      expect(stats.maxBpmCompleted, isTrue);
    });

    test('uma execução: sem comparação', () {
      final stats = EvolutionStats.from(_history(1, structure));
      expect(stats.averageDelta, isNull);
      expect(stats.trend, EvolutionTrend.unknown);
      expect(stats.previous, isNull);
    });

    test('média móvel das últimas 3', () {
      expect(EvolutionStats.movingAverage([60, 90, 30, 60]), [60, 75, 60, 60]);
    });
  });

  group('aba Evolução', () {
    for (final light in [false, true]) {
      final mode = light ? 'claro' : 'escuro';

      testWidgets('resumo, gráfico e lista – modo $mode', (tester) async {
        final key = GlobalKey();
        final history = _history(12, structure);
        await _pumpResult(tester, history, light: light, boundary: key);

        await tester.tap(find.text('Evolução'));
        await tester.pumpAndSettle();

        expect(find.text('Sua evolução nesta música'), findsOneWidget);
        expect(find.text('Melhor pontuação'), findsOneWidget);
        expect(find.text('Média das últimas 5'), findsOneWidget);
        expect(find.text('Em evolução'), findsOneWidget);
        expect(find.text('102 BPM'), findsWidgets);
        expect(find.text('Maior andamento'), findsOneWidget);
        expect(find.byType(PerformanceChart), findsOneWidget);
        expect(find.byType(PerformanceChartLegend), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _scrollTo(tester, find.byType(PerformanceChart));
        await _screenshot(tester, key, 'evolucao_grafico_$mode');

        // Toque no gráfico: execução mais próxima selecionada, com o botão
        // para abri-la.
        final chart = tester.getRect(find.byType(PerformanceChart));
        await tester.tapAt(Offset(chart.left + 44, chart.center.dy));
        await tester.pumpAndSettle();
        expect(find.text('Ver execução'), findsOneWidget);
        await _screenshot(tester, key, 'evolucao_selecao_$mode');

        await _scrollTo(tester, find.text('3ª execução'));
        await _screenshot(tester, key, 'evolucao_lista_$mode');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('antes da 10ª execução o gráfico mostra quanto falta (RFA11)', (tester) async {
      await _pumpResult(tester, _history(4, structure));
      await tester.tap(find.text('Evolução'));
      await tester.pumpAndSettle();

      expect(find.byType(PerformanceChart), findsNothing);
      expect(find.text('Faltam 6 execuções desta música para liberar o gráfico.'), findsOneWidget);
      expect(find.text('4/10'), findsOneWidget);
      expect(find.text('4ª execução'), findsOneWidget);
    });

    testWidgets('filtros de série e período no gráfico', (tester) async {
      await _pumpResult(tester, _history(14, structure), size: const Size(1440, 900));
      await tester.tap(find.text('Evolução'));
      await tester.pumpAndSettle();

      // Execuções antigas não têm altura: o gráfico de Altura começa na 3ª.
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(tester.widget<PerformanceChart>(find.byType(PerformanceChart)).values, hasLength(14));
      await tester.tap(find.text('Altura'));
      await tester.pumpAndSettle();
      final chart = tester.widget<PerformanceChart>(find.byType(PerformanceChart));
      expect(chart.values, hasLength(12));
      expect(chart.firstOrdinal, 3);
      expect(find.text('Altura (notas certas) por execução'), findsOneWidget);

      await tester.tap(find.text('Últimas 10'));
      await tester.pumpAndSettle();
      expect(tester.widget<PerformanceChart>(find.byType(PerformanceChart)).values, hasLength(10));
      expect(tester.takeException(), isNull);
    });
  });

  group('execução anterior', () {
    for (final light in [false, true]) {
      final mode = light ? 'claro' : 'escuro';

      testWidgets('tocar na execução abre a mesma tela do fim da execução – modo $mode',
          (tester) async {
        final key = GlobalKey();
        final history = _history(12, structure);
        await _pumpResult(tester, history, light: light, boundary: key);
        await tester.tap(find.text('Evolução'));
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('3ª execução'));
        await tester.tap(find.text('3ª execução'));
        await tester.pumpAndSettle();

        // Mesma tela: resumo, avaliação, abas e notas da execução salva.
        expect(find.byType(PastPerformancePage), findsOneWidget);
        expect(find.text('Resumo da performance'), findsOneWidget);
        expect(find.textContaining('3ª execução ·'), findsOneWidget);
        expect(find.text('Muito bem!'), findsNothing); // 61% → "Bom trabalho!"
        expect(find.text('Bom trabalho!'), findsOneWidget);
        expect(find.byType(ScoreResultWidget), findsOneWidget);
        expect(find.text('1: 68%'), findsOneWidget); // trecho salvo
        expect(find.text('Notas executadas'), findsOneWidget);
        expect(find.text('TOCAR NOVAMENTE'), findsOneWidget);

        final page = tester.widget<PerformanceResultPage>(find.byType(PerformanceResultPage));
        expect(page.execution!.executionId, 'exec2');
        expect(page.precision, 61);
        expect(page.bestStreak, 9);
        expect(page.structure, isNotNull);
        expect(page.feedback, _phraseFeedback(structure));
        expect(tester.takeException(), isNull);
        await _screenshot(tester, key, 'execucao_anterior_$mode');

        // A evolução destaca a execução aberta.
        await tester.tap(find.text('Evolução'));
        await tester.pumpAndSettle();
        expect(find.text('Aberta'), findsWidgets);

        // Voltar leva ao resumo da execução que acabou de terminar.
        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(find.byType(PastPerformancePage), findsNothing);
        expect(find.byType(PerformanceResultPage), findsOneWidget);
      });
    }

    testWidgets('execução antiga sem resultado nota a nota', (tester) async {
      await _pumpResult(tester, _history(12, structure));
      await tester.tap(find.text('Evolução'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('1ª execução'));
      await tester.tap(find.text('1ª execução'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1ª execução ·'), findsOneWidget);
      expect(find.textContaining('salva antes do registro nota a nota'), findsOneWidget);
      // Sem altura/ritmo salvos: sem o quadro de avaliação.
      expect(find.byType(ScoreResultWidget), findsNothing);
      expect(find.text('--'), findsOneWidget); // notas tocadas desconhecidas
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('EvolutionPanel isolado: gráfico com cores do tema', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvolutionPanel(history: _history(10, structure), now: _now),
          ),
        ),
      ),
    );
    expect(find.byType(PerformanceChart), findsOneWidget);
    expect(find.text('Hoje, 16:00'), findsOneWidget);
    expect(find.text('Ontem, 16:00'), findsOneWidget);
    expect(AppColors.of(tester.element(find.byType(PerformanceChart))), AppColors.light);
  });
}

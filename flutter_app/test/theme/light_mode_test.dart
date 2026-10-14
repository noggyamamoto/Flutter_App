// Modo claro (Configurações > Aparência): o escuro é o padrão; a escolha
// troca o tema do app inteiro na hora e fica salva no aparelho.
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/configuration/presentation/pages/configuration_page.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  // Firebase "iniciando": o app fica na abertura, sem rede nos testes.
  final firebase = Completer<FirebaseApp>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [firebaseInitProvider.overrideWith((ref) => firebase.future)],
      child: const MyApp(),
    ),
  );
  await tester.pump();
}

Color _background(WidgetTester tester, Finder page) {
  final scaffold = tester.widget<Scaffold>(
    find.descendant(of: page, matching: find.byType(Scaffold)).first,
  );
  return scaffold.backgroundColor!;
}

void main() {
  test('paletas: mesmo violeta nos dois modos, fundos e textos invertidos', () {
    const dark = AppColors.dark;
    const light = AppColors.light;

    expect(dark.isDark, isTrue);
    expect(light.isDark, isFalse);
    expect(light.primary, dark.primary);
    expect(dark.background, const Color(0xFF0F0E17));
    expect(light.background.computeLuminance(), greaterThan(0.85));
    expect(light.textPrimary.computeLuminance(), lessThan(0.05));

    // Texto principal legível sobre o fundo e as superfícies (WCAG AA).
    double contrast(Color text, Color surface) {
      final a = Color.alphaBlend(text, surface).computeLuminance();
      final b = surface.computeLuminance();
      return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    }

    for (final c in [dark, light]) {
      for (final surface in [c.background, c.surface, c.card]) {
        expect(contrast(c.textPrimary, surface), greaterThan(7));
        expect(contrast(c.textSecondary, surface), greaterThan(4.5));
      }
    }

    expect(AppTheme.dark.extension<AppColors>(), dark);
    expect(AppTheme.light.extension<AppColors>(), light);
  });

  testWidgets('modo escuro é o padrão', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(_background(tester, find.byType(MaterialApp)), AppColors.dark.background);
  });

  testWidgets('modo claro salvo é usado na abertura', (tester) async {
    SharedPreferences.setMockInitialValues({'config.lightMode': true});
    await _pumpApp(tester);
    // Preferência lida + transição do tema (a abertura gira sem parar).
    await tester.pump(const Duration(milliseconds: 500));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(_background(tester, find.byType(MaterialApp)), AppColors.light.background);
  });

  testWidgets('Configurações > Aparência troca o tema e salva a escolha', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpApp(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(builder: (_) => const ConfigurationPage()),
        );
    await tester.pumpAndSettle();

    final page = find.byType(ConfigurationPage);
    expect(find.text('Aparência'), findsOneWidget);
    expect(_background(tester, page), AppColors.dark.background);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.light);
    expect(_background(tester, page), AppColors.light.background);
    // Textos da tela também mudam (tinta escura sobre o fundo claro).
    final title = tester.widget<Text>(find.text('Tema'));
    expect(title.style!.color, AppColors.light.textPrimary);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('config.lightMode'), isTrue);

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(_background(tester, page), AppColors.dark.background);
    expect(prefs.getBool('config.lightMode'), isFalse);
    expect(tester.takeException(), isNull);
  });
}

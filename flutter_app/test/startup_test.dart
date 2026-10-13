// Abertura do app: a primeira tela aparece na hora, enquanto o Firebase é
// iniciado em paralelo (antes, a tela ficava em branco até ele terminar).
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('abertura aparece enquanto o Firebase inicia', (tester) async {
    final firebase = Completer<FirebaseApp>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseInitProvider.overrideWith((ref) => firebase.future)],
        child: const MyApp(),
      ),
    );

    expect(find.text('Partitura IoT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('falha ao iniciar oferece tentar novamente', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseInitProvider.overrideWith((ref) {
            attempts++;
            return Future<FirebaseApp>.error(Exception('sem rede'));
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Não foi possível iniciar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(attempts, 2);
  });
}

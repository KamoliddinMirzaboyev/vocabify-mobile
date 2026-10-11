import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/main.dart';
import 'package:vocabify_app/providers/auth_provider.dart';

void main() {
  testWidgets('renders the splash while core initialization is pending', (
    tester,
  ) async {
    final pendingInitialization = Completer<void>();

    await tester.pumpWidget(
      buildVocabifyApp(coreInitialization: pendingInitialization.future),
    );

    expect(find.text('Vocabify'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let SplashScreen's bounded polling timer finish before disposal. The
    // initialization future intentionally remains pending for this scenario.
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  test('auth initialization fails gracefully when bootstrap fails', () async {
    final provider = AuthProvider(
      coreInitialization: Future<void>.error(StateError('bootstrap failed')),
    );

    await Future<void>.delayed(Duration.zero);

    expect(provider.isLoading, isFalse);
    expect(provider.isAuthenticated, isFalse);
    provider.dispose();
  });
}

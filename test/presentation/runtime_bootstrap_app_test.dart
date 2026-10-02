import 'dart:async';

import 'package:budget_accounting_system/src/bootstrap/database_encryption_bootstrap.dart';
import 'package:budget_accounting_system/src/bootstrap/runtime_bootstrap_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('renders a Flutter progress frame before runtime is ready', (
    tester,
  ) async {
    final completer = Completer<AppRuntime>();

    await tester.pumpWidget(
      RuntimeBootstrapApp(loadRuntime: () => completer.future),
    );

    expect(
      find.byKey(const ValueKey('runtime-bootstrap-progress')),
      findsOneWidget,
    );
  });

  testWidgets('shows retry UI when runtime bootstrap fails', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          attempts += 1;
          throw StateError('startup failed');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('runtime-bootstrap-error')),
      findsOneWidget,
    );
    expect(find.text('Не удалось запустить приложение'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('runtime-bootstrap-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });

  testWidgets('explains missing encrypted database key', (tester) async {
    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          throw const DatabaseKeyMissingException();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть локальные данные'), findsOneWidget);
    expect(find.textContaining('не удаляйте приложение'), findsOneWidget);
  });

  testWidgets('continues to normal app when runtime loads', (tester) async {
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
    );

    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async => AppRuntime(services: services),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Первый бюджет'), findsOneWidget);
  });
}

import 'package:budget_accounting_system/src/presentation/screens/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('switches between main application sections', (tester) async {
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          services: services,
          userId: 'user-1',
          budgetId: 'budget-1',
          budgetName: 'Дом',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('budget-dashboard')), findsOneWidget);
    expect(find.text('Дом'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section-planning')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section-reports')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-management')), findsOneWidget);
  });
}

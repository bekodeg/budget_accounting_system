import 'package:budget_accounting_system/src/app.dart';
import 'package:budget_accounting_system/src/application/app_services.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_user_budgets.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/repositories/budget_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches between main application sections', (tester) async {
    final services = AppServices(
      watchUserBudgets: WatchUserBudgets(_EmptyBudgetRepository()),
    );

    await tester.pumpWidget(
      BudgetAccountingApp(services: services),
    );

    expect(find.byKey(const ValueKey('section-transactions')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section-planning')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section-reports')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section-settings')), findsOneWidget);
  });
}

final class _EmptyBudgetRepository implements BudgetRepository {
  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    return Stream.value(const []);
  }
}

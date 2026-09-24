import 'package:budget_accounting_system/src/domain/models/dashboard_summary.dart';
import 'package:budget_accounting_system/src/presentation/screens/budget_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('shows monthly metrics and opens quick transaction editor', (
    tester,
  ) async {
    final dashboard = FakeDashboardRepository(
      summary: DashboardSummary(
        monthStart: DateTime(2026, 9),
        incomeMinorByCurrency: {
          'EUR': BigInt.from(125000),
          'USD': BigInt.from(5000),
        },
        expenseMinorByCurrency: {
          'EUR': BigInt.from(45000),
        },
        balanceMinorByCurrency: {
          'EUR': BigInt.from(80000),
          'USD': BigInt.from(5000),
        },
      ),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      dashboardRepository: dashboard,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetDashboardScreen(
            services: services,
            budgetId: 'budget-1',
            userId: 'user-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget-dashboard')), findsOneWidget);
    expect(find.text('1250.00 EUR'), findsOneWidget);
    expect(find.text('50.00 USD'), findsNWidgets(3));
    expect(find.text('800.00 EUR'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('dashboard-quick-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transaction-editor')), findsOneWidget);
  });

  testWidgets('reactively updates dashboard metrics', (tester) async {
    final dashboard = FakeDashboardRepository(
      summary: DashboardSummary(
        monthStart: DateTime(2026, 9),
        incomeMinorByCurrency: {'EUR': BigInt.from(1000)},
        expenseMinorByCurrency: const {},
        balanceMinorByCurrency: {'EUR': BigInt.from(1000)},
      ),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      dashboardRepository: dashboard,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetDashboardScreen(
            services: services,
            budgetId: 'budget-1',
            userId: 'user-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10.00 EUR'), findsNWidgets(3));

    dashboard.emit(
      DashboardSummary(
        monthStart: DateTime(2026, 9),
        incomeMinorByCurrency: {'EUR': BigInt.from(2000)},
        expenseMinorByCurrency: {'EUR': BigInt.from(500)},
        balanceMinorByCurrency: {'EUR': BigInt.from(1500)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20.00 EUR'), findsOneWidget);
    expect(find.text('5.00 EUR'), findsOneWidget);
    expect(find.text('15.00 EUR'), findsNWidgets(2));
  });
}

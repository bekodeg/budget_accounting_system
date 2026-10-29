import 'package:budget_accounting_system/src/domain/models/account_balance.dart';
import 'package:budget_accounting_system/src/domain/models/monthly_report.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/presentation/screens/monthly_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  MonthlyReport report({required int actualMinor}) {
    return MonthlyReport(
      monthStart: DateTime(2026, 9),
      baseCurrency: 'EUR',
      incomeMinorByCurrency: {'EUR': BigInt.from(10000)},
      expenseMinorByCurrency: {'EUR': BigInt.from(actualMinor)},
      categories: [
        MonthlyCategoryReport(
          categoryId: 'food',
          categoryName: 'Еда',
          planCurrency: 'EUR',
          plannedAmountMinor: BigInt.from(10000),
          actualMinorByCurrency: {'EUR': BigInt.from(actualMinor)},
        ),
      ],
      accountBalances: [
        MonthlyAccountReportBalance(
          accountId: 'cash',
          accountName: 'Наличные',
          balance: AccountBalance(
            accountId: 'cash',
            minorUnits: BigInt.from(5000),
            currency: Currency('EUR'),
          ),
          isArchived: false,
        ),
      ],
    );
  }

  testWidgets('shows plan fact balances and updates reactively', (
    tester,
  ) async {
    final reports = FakeMonthlyReportRepository(
      report: report(actualMinor: 7000),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      monthlyReportRepository: reports,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyReportScreen(
            services: services,
            budgetId: 'budget-1',
            initialMonth: DateTime(2026, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('monthly-report-screen')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-category-food')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Еда'), findsWidgets);
    expect(find.text('План: 100.00 EUR'), findsOneWidget);
    expect(find.text('Факт: 70.00 EUR'), findsOneWidget);
    expect(find.text('Остаток: 30.00 EUR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-account-cash')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('50.00 EUR'), findsOneWidget);

    reports.emit(report(actualMinor: 8000));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-category-food')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Факт: 80.00 EUR'), findsOneWidget);
    expect(find.text('Остаток: 20.00 EUR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monthly-category-pie-chart')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-category-pie-chart')),
        matching: find.textContaining('80.00 EUR (100.0%)'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pie changes currency while plan fact stays in base currency', (
    tester,
  ) async {
    final reports = FakeMonthlyReportRepository(
      report: MonthlyReport(
        monthStart: DateTime(2026, 9),
        baseCurrency: 'EUR',
        incomeMinorByCurrency: const {},
        expenseMinorByCurrency: {
          'EUR': BigInt.from(2000),
          'USD': BigInt.from(500),
        },
        categories: [
          MonthlyCategoryReport(
            categoryId: 'food',
            categoryName: 'Еда',
            planCurrency: 'EUR',
            plannedAmountMinor: BigInt.from(3000),
            actualMinorByCurrency: {
              'EUR': BigInt.from(2000),
              'USD': BigInt.from(500),
            },
          ),
        ],
        accountBalances: const [],
      ),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      monthlyReportRepository: reports,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyReportScreen(
            services: services,
            budgetId: 'budget-1',
            initialMonth: DateTime(2026, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('monthly-category-pie-chart')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-category-pie-chart')),
        matching: find.textContaining('20.00 EUR (100.0%)'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('report-chart-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-category-pie-chart')),
        matching: find.textContaining('5.00 USD (100.0%)'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monthly-plan-fact-chart')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Сравнение только в базовой валюте · EUR'),
      findsOneWidget,
    );
  });

  testWidgets('empty month shows explicit chart states and period changes', (
    tester,
  ) async {
    final reports = FakeMonthlyReportRepository();
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      monthlyReportRepository: reports,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyReportScreen(
            services: services,
            budgetId: 'budget-1',
            initialMonth: DateTime(2026, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Нет расходов в EUR за выбранный период.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('report-next-month')));
    await tester.pumpAndSettle();
    expect(reports.lastRequestedMonth, DateTime(2026, 10));
    expect(
      find.byKey(const ValueKey('monthly-category-pie-chart')),
      findsOneWidget,
    );
  });
}

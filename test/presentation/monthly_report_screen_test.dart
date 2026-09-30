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

  testWidgets('shows plan fact balances and updates reactively', (tester) async {
    final reports = FakeMonthlyReportRepository(report: report(actualMinor: 7000));
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
    expect(find.text('Еда'), findsOneWidget);
    expect(find.text('План: 100.00 EUR'), findsOneWidget);
    expect(find.text('Факт: 70.00 EUR'), findsOneWidget);
    expect(find.text('Остаток: 30.00 EUR'), findsOneWidget);
    expect(find.text('50.00 EUR'), findsOneWidget);

    reports.emit(report(actualMinor: 8000));
    await tester.pumpAndSettle();

    expect(find.text('Факт: 80.00 EUR'), findsOneWidget);
    expect(find.text('Остаток: 20.00 EUR'), findsOneWidget);
  });
}

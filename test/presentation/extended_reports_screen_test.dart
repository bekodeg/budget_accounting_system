import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/period_report.dart';
import 'package:budget_accounting_system/src/domain/models/year_report.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/presentation/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('switches between month year and period reports', (tester) async {
    final extended = FakeExtendedReportRepository(
      yearReport: YearReport(
        year: 2026,
        baseCurrency: 'EUR',
        months: [
          for (var month = 1; month <= 12; month++)
            YearMonthReport(
              monthStart: DateTime(2026, month),
              incomeMinorByCurrency: month == 1
                  ? {'EUR': BigInt.from(10000)}
                  : const {},
              expenseMinorByCurrency: const {},
              plannedAmountMinor: BigInt.zero,
              actualBaseCurrencyMinor: BigInt.zero,
            ),
        ],
        categories: const [],
      ),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      extendedReportRepository: extended,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportsScreen(
            services: services,
            budgetId: 'budget-1',
            userId: 'user-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reports-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('monthly-report-screen')), findsOneWidget);

    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('year-report-screen')), findsOneWidget);
    expect(find.text('100.00 EUR'), findsWidgets);

    await tester.tap(find.text('Период'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('period-report-screen')), findsOneWidget);
  });

  testWidgets('period UI builds plural category account and author filters', (
    tester,
  ) async {
    final extended = FakeExtendedReportRepository(
      periodReport: PeriodReport(
        fromInclusive: DateTime(2026, 9),
        toExclusive: DateTime(2026, 10),
        incomeMinorByCurrency: const {},
        expenseMinorByCurrency: const {},
        categories: const [],
      ),
    );
    final categories = FakeCategoryRepository(
      categoriesByBudget: {
        'budget-1': const [
          BudgetCategory(
            id: 'food',
            budgetId: 'budget-1',
            name: 'Еда',
            kind: CategoryKind.expense,
            isArchived: false,
          ),
          BudgetCategory(
            id: 'transport',
            budgetId: 'budget-1',
            name: 'Транспорт',
            kind: CategoryKind.expense,
            isArchived: false,
          ),
        ],
      },
    );
    final accounts = FakeAccountRepository(
      accountsByBudget: {
        'budget-1': [
          BudgetAccount(
            id: 'cash',
            budgetId: 'budget-1',
            name: 'Наличные',
            openingBalanceMinor: BigInt.zero,
            currency: Currency('EUR'),
            isArchived: false,
          ),
          BudgetAccount(
            id: 'card',
            budgetId: 'budget-1',
            name: 'Карта',
            openingBalanceMinor: BigInt.zero,
            currency: Currency('EUR'),
            isArchived: false,
          ),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      categoryRepository: categories,
      accountRepository: accounts,
      extendedReportRepository: extended,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeriodReportScreen(
            services: services,
            budgetId: 'budget-1',
            userId: 'user-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('period-category-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-category-transport')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-account-cash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('period-only-mine')));
    await tester.pumpAndSettle();

    final filter = extended.lastPeriodFilter!;
    expect(filter.categoryIds, {'food', 'transport'});
    expect(filter.accountIds, {'cash'});
    expect(filter.authorIds, {'user-1'});
  });
}

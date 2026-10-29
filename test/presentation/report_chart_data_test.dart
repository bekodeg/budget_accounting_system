import 'package:budget_accounting_system/src/domain/models/monthly_report.dart';
import 'package:budget_accounting_system/src/domain/models/year_report.dart';
import 'package:budget_accounting_system/src/presentation/report_charts/report_chart_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly charts keep currencies separate and include uncategorized', () {
    final report = MonthlyReport(
      monthStart: DateTime(2026, 9),
      baseCurrency: 'EUR',
      incomeMinorByCurrency: const {},
      expenseMinorByCurrency: {
        'EUR': BigInt.from(3000),
        'USD': BigInt.from(500),
      },
      categories: [
        MonthlyCategoryReport(
          categoryId: 'food',
          categoryName: 'Еда',
          planCurrency: 'EUR',
          plannedAmountMinor: BigInt.from(5000),
          actualMinorByCurrency: {
            'EUR': BigInt.from(2000),
            'USD': BigInt.from(500),
          },
        ),
        MonthlyCategoryReport(
          categoryId: null,
          categoryName: 'Без категории',
          planCurrency: 'EUR',
          plannedAmountMinor: BigInt.zero,
          actualMinorByCurrency: {'EUR': BigInt.from(1000)},
        ),
        MonthlyCategoryReport(
          categoryId: 'empty',
          categoryName: 'План без расходов',
          planCurrency: 'EUR',
          plannedAmountMinor: BigInt.from(3000),
          actualMinorByCurrency: const {},
        ),
      ],
      accountBalances: const [],
    );

    expect(reportCurrencies('EUR', report.expenseMinorByCurrency), [
      'EUR',
      'USD',
    ]);
    final eur = monthlyCategoryExpenses(report, 'EUR');
    expect(eur.map((item) => item.name), ['Еда', 'Без категории']);
    expect(
      eur.fold(BigInt.zero, (sum, item) => sum + item.amountMinor),
      BigInt.from(3000),
    );
    final usd = monthlyCategoryExpenses(report, 'USD');
    expect(usd, hasLength(1));
    expect(usd.single.amountMinor, BigInt.from(500));

    final planFact = monthlyPlanFact(report);
    expect(planFact, hasLength(3));
    expect(planFact.first.planMinor, BigInt.from(5000));
    expect(planFact.first.actualMinor, BigInt.from(2000));
    expect(planFact.last.actualMinor, BigInt.zero);
  });

  test('year charts use selected currency and retain all 12 months', () {
    final report = YearReport(
      year: 2026,
      baseCurrency: 'EUR',
      months: [
        for (var month = 1; month <= 12; month++)
          YearMonthReport(
            monthStart: DateTime(2026, month),
            incomeMinorByCurrency: const {},
            expenseMinorByCurrency: month == 1
                ? {'EUR': BigInt.from(1200), 'USD': BigInt.from(500)}
                : month == 2
                ? {'EUR': BigInt.from(800)}
                : const {},
            plannedAmountMinor: BigInt.zero,
            actualBaseCurrencyMinor: BigInt.zero,
          ),
      ],
      categories: [
        YearCategoryReport(
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
    );

    final eur = yearMonthExpenses(report, 'EUR');
    expect(eur, hasLength(12));
    expect(eur[0].amountMinor, BigInt.from(1200));
    expect(eur[1].amountMinor, BigInt.from(800));
    expect(eur[11].amountMinor, BigInt.zero);
    expect(yearMonthExpenses(report, 'USD')[1].amountMinor, BigInt.zero);
    expect(
      yearCategoryExpenses(report, 'USD').single.amountMinor,
      BigInt.from(500),
    );
    expect(yearCategoryExpenses(report, 'GBP'), isEmpty);
  });
}

import '../../domain/models/monthly_report.dart';
import '../../domain/models/year_report.dart';

final class CategoryExpenseValue {
  const CategoryExpenseValue({
    required this.id,
    required this.name,
    required this.amountMinor,
  });

  final String? id;
  final String name;
  final BigInt amountMinor;
}

final class CategoryPlanFactValue {
  const CategoryPlanFactValue({
    required this.id,
    required this.name,
    required this.planMinor,
    required this.actualMinor,
  });

  final String? id;
  final String name;
  final BigInt planMinor;
  final BigInt actualMinor;
}

final class MonthExpenseValue {
  const MonthExpenseValue({required this.month, required this.amountMinor});

  final int month;
  final BigInt amountMinor;
}

List<String> reportCurrencies(
  String baseCurrency,
  Map<String, BigInt> expenses,
) {
  final other =
      expenses.keys.where((currency) => currency != baseCurrency).toList()
        ..sort();
  return [baseCurrency, ...other];
}

List<CategoryExpenseValue> monthlyCategoryExpenses(
  MonthlyReport report,
  String currency,
) => [
  for (final category in report.categories)
    if ((category.actualMinorByCurrency[currency] ?? BigInt.zero) > BigInt.zero)
      CategoryExpenseValue(
        id: category.categoryId,
        name: category.categoryName,
        amountMinor: category.actualMinorByCurrency[currency]!,
      ),
];

List<CategoryExpenseValue> yearCategoryExpenses(
  YearReport report,
  String currency,
) => [
  for (final category in report.categories)
    if ((category.actualMinorByCurrency[currency] ?? BigInt.zero) > BigInt.zero)
      CategoryExpenseValue(
        id: category.categoryId,
        name: category.categoryName,
        amountMinor: category.actualMinorByCurrency[currency]!,
      ),
];

List<CategoryPlanFactValue> monthlyPlanFact(MonthlyReport report) => [
  for (final category in report.categories)
    CategoryPlanFactValue(
      id: category.categoryId,
      name: category.categoryName,
      planMinor: category.plannedAmountMinor,
      actualMinor: category.actualPlanCurrencyMinor,
    ),
];

List<MonthExpenseValue> yearMonthExpenses(YearReport report, String currency) =>
    [
      for (final month in report.months)
        MonthExpenseValue(
          month: month.monthStart.month,
          amountMinor: month.expenseMinorByCurrency[currency] ?? BigInt.zero,
        ),
    ];

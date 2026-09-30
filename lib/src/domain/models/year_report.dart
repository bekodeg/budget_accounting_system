final class YearMonthReport {
  YearMonthReport({
    required this.monthStart,
    required Map<String, BigInt> incomeMinorByCurrency,
    required Map<String, BigInt> expenseMinorByCurrency,
    required this.plannedAmountMinor,
    required this.actualBaseCurrencyMinor,
  }) : incomeMinorByCurrency = Map.unmodifiable(incomeMinorByCurrency),
       expenseMinorByCurrency = Map.unmodifiable(expenseMinorByCurrency);

  final DateTime monthStart;
  final Map<String, BigInt> incomeMinorByCurrency;
  final Map<String, BigInt> expenseMinorByCurrency;
  final BigInt plannedAmountMinor;
  final BigInt actualBaseCurrencyMinor;

  BigInt get varianceMinor => plannedAmountMinor - actualBaseCurrencyMinor;

  Map<String, BigInt> get netMinorByCurrency {
    final currencies = <String>{
      ...incomeMinorByCurrency.keys,
      ...expenseMinorByCurrency.keys,
    };
    return Map.unmodifiable({
      for (final currency in currencies)
        currency:
            (incomeMinorByCurrency[currency] ?? BigInt.zero) -
            (expenseMinorByCurrency[currency] ?? BigInt.zero),
    });
  }
}

final class YearCategoryReport {
  YearCategoryReport({
    required this.categoryId,
    required this.categoryName,
    required this.planCurrency,
    required this.plannedAmountMinor,
    required Map<String, BigInt> actualMinorByCurrency,
  }) : actualMinorByCurrency = Map.unmodifiable(actualMinorByCurrency);

  final String? categoryId;
  final String categoryName;
  final String planCurrency;
  final BigInt plannedAmountMinor;
  final Map<String, BigInt> actualMinorByCurrency;

  BigInt get actualPlanCurrencyMinor =>
      actualMinorByCurrency[planCurrency] ?? BigInt.zero;

  BigInt get varianceMinor => plannedAmountMinor - actualPlanCurrencyMinor;
}

final class YearReport {
  YearReport({
    required this.year,
    required this.baseCurrency,
    required List<YearMonthReport> months,
    required List<YearCategoryReport> categories,
  }) : months = List.unmodifiable(months),
       categories = List.unmodifiable(categories);

  final int year;
  final String baseCurrency;
  final List<YearMonthReport> months;
  final List<YearCategoryReport> categories;

  Map<String, BigInt> get incomeMinorByCurrency =>
      _sumCurrencyMaps(months.map((month) => month.incomeMinorByCurrency));

  Map<String, BigInt> get expenseMinorByCurrency =>
      _sumCurrencyMaps(months.map((month) => month.expenseMinorByCurrency));

  Map<String, BigInt> get netMinorByCurrency {
    final income = incomeMinorByCurrency;
    final expense = expenseMinorByCurrency;
    final currencies = <String>{...income.keys, ...expense.keys};
    return Map.unmodifiable({
      for (final currency in currencies)
        currency:
            (income[currency] ?? BigInt.zero) -
            (expense[currency] ?? BigInt.zero),
    });
  }

  BigInt get plannedAmountMinor => months.fold(
    BigInt.zero,
    (sum, month) => sum + month.plannedAmountMinor,
  );

  BigInt get actualBaseCurrencyMinor => months.fold(
    BigInt.zero,
    (sum, month) => sum + month.actualBaseCurrencyMinor,
  );

  BigInt get varianceMinor => plannedAmountMinor - actualBaseCurrencyMinor;
}

Map<String, BigInt> _sumCurrencyMaps(
  Iterable<Map<String, BigInt>> values,
) {
  final result = <String, BigInt>{};
  for (final value in values) {
    for (final entry in value.entries) {
      result[entry.key] = (result[entry.key] ?? BigInt.zero) + entry.value;
    }
  }
  return Map.unmodifiable(result);
}

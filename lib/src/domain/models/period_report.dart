final class PeriodCategoryTotal {
  PeriodCategoryTotal({
    required this.categoryId,
    required this.categoryName,
    required Map<String, BigInt> actualMinorByCurrency,
  }) : actualMinorByCurrency = Map.unmodifiable(actualMinorByCurrency);

  final String? categoryId;
  final String categoryName;
  final Map<String, BigInt> actualMinorByCurrency;
}

final class PeriodReport {
  PeriodReport({
    required this.fromInclusive,
    required this.toExclusive,
    required Map<String, BigInt> incomeMinorByCurrency,
    required Map<String, BigInt> expenseMinorByCurrency,
    required List<PeriodCategoryTotal> categories,
  }) : incomeMinorByCurrency = Map.unmodifiable(incomeMinorByCurrency),
       expenseMinorByCurrency = Map.unmodifiable(expenseMinorByCurrency),
       categories = List.unmodifiable(categories);

  final DateTime fromInclusive;
  final DateTime toExclusive;
  final Map<String, BigInt> incomeMinorByCurrency;
  final Map<String, BigInt> expenseMinorByCurrency;
  final List<PeriodCategoryTotal> categories;

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

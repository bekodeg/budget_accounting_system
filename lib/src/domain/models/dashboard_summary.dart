final class DashboardSummary {
  DashboardSummary({
    required this.monthStart,
    required Map<String, BigInt> incomeMinorByCurrency,
    required Map<String, BigInt> expenseMinorByCurrency,
    required Map<String, BigInt> balanceMinorByCurrency,
  })  : incomeMinorByCurrency = Map.unmodifiable(incomeMinorByCurrency),
        expenseMinorByCurrency = Map.unmodifiable(expenseMinorByCurrency),
        balanceMinorByCurrency = Map.unmodifiable(balanceMinorByCurrency);

  final DateTime monthStart;
  final Map<String, BigInt> incomeMinorByCurrency;
  final Map<String, BigInt> expenseMinorByCurrency;
  final Map<String, BigInt> balanceMinorByCurrency;

  Map<String, BigInt> get netMinorByCurrency {
    final currencies = <String>{
      ...incomeMinorByCurrency.keys,
      ...expenseMinorByCurrency.keys,
    };
    return Map.unmodifiable({
      for (final currency in currencies)
        currency: (incomeMinorByCurrency[currency] ?? BigInt.zero) -
            (expenseMinorByCurrency[currency] ?? BigInt.zero),
    });
  }
}

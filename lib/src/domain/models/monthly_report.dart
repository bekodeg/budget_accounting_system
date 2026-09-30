import 'account_balance.dart';

final class MonthlyCategoryReport {
  MonthlyCategoryReport({
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

  BigInt get remainingMinor => plannedAmountMinor - actualPlanCurrencyMinor;
}

final class MonthlyAccountReportBalance {
  const MonthlyAccountReportBalance({
    required this.accountId,
    required this.accountName,
    required this.balance,
    required this.isArchived,
  });

  final String accountId;
  final String accountName;
  final AccountBalance balance;
  final bool isArchived;
}

final class MonthlyReport {
  MonthlyReport({
    required this.monthStart,
    required this.baseCurrency,
    required Map<String, BigInt> incomeMinorByCurrency,
    required Map<String, BigInt> expenseMinorByCurrency,
    required List<MonthlyCategoryReport> categories,
    required List<MonthlyAccountReportBalance> accountBalances,
  }) : incomeMinorByCurrency = Map.unmodifiable(incomeMinorByCurrency),
       expenseMinorByCurrency = Map.unmodifiable(expenseMinorByCurrency),
       categories = List.unmodifiable(categories),
       accountBalances = List.unmodifiable(accountBalances);

  final DateTime monthStart;
  final String baseCurrency;
  final Map<String, BigInt> incomeMinorByCurrency;
  final Map<String, BigInt> expenseMinorByCurrency;
  final List<MonthlyCategoryReport> categories;
  final List<MonthlyAccountReportBalance> accountBalances;

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

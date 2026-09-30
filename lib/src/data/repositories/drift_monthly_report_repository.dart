import '../../domain/models/account_balance.dart';
import '../../domain/models/monthly_report.dart';
import '../../domain/repositories/monthly_report_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../dal/report_dao.dart';

final class DriftMonthlyReportRepository implements MonthlyReportRepository {
  const DriftMonthlyReportRepository(this._reports);

  final ReportDao _reports;

  @override
  Stream<MonthlyReport> watchMonthlyReport({
    required String budgetId,
    required DateTime monthStart,
  }) {
    return _reports
        .watchMonthlyReportRows(
          budgetId: budgetId,
          monthStart: monthStart,
        )
        .map((rows) => _mapRows(rows, monthStart));
  }

  MonthlyReport _mapRows(
    List<MonthlyReportRow> rows,
    DateTime monthStart,
  ) {
    final baseRow = rows.where((row) => row.kind == 'BASE').firstOrNull;
    if (baseRow == null || baseRow.currency == null) {
      throw StateError('Budget base currency is missing for monthly report.');
    }
    final baseCurrency = baseRow.currency!;

    final income = <String, BigInt>{};
    final expense = <String, BigInt>{};
    final categoryBuilders = <String, _CategoryBuilder>{};
    final accounts = <MonthlyAccountReportBalance>[];

    for (final row in rows) {
      switch (row.kind) {
        case 'BASE':
          break;
        case 'FLOW':
          final currency = row.currency!;
          if (row.keyId == 'INCOME') {
            income[currency] = row.amountMinor;
          } else if (row.keyId == 'EXPENSE') {
            expense[currency] = row.amountMinor;
          }
        case 'CATEGORY_ACTUAL':
          final key = row.keyId ?? '';
          final builder = categoryBuilders.putIfAbsent(
            key,
            () => _CategoryBuilder(
              categoryId: key.isEmpty ? null : key,
              categoryName: row.label ?? 'Без категории',
            ),
          );
          builder.actual[row.currency!] = row.amountMinor;
        case 'CATEGORY_PLAN':
          final key = row.keyId!;
          final builder = categoryBuilders.putIfAbsent(
            key,
            () => _CategoryBuilder(
              categoryId: key,
              categoryName: row.label ?? 'Категория',
            ),
          );
          builder.plannedAmountMinor = row.amountMinor;
        case 'ACCOUNT':
          accounts.add(
            MonthlyAccountReportBalance(
              accountId: row.keyId!,
              accountName: row.label ?? row.keyId!,
              balance: AccountBalance(
                accountId: row.keyId!,
                minorUnits: row.amountMinor,
                currency: Currency(row.currency!),
              ),
              isArchived: row.flag == 1,
            ),
          );
        default:
          throw StateError('Unsupported monthly report row: ${row.kind}');
      }
    }

    final categories = categoryBuilders.values
        .map(
          (builder) => MonthlyCategoryReport(
            categoryId: builder.categoryId,
            categoryName: builder.categoryName,
            planCurrency: baseCurrency,
            plannedAmountMinor: builder.plannedAmountMinor,
            actualMinorByCurrency: builder.actual,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) {
        final byName = a.categoryName.compareTo(b.categoryName);
        if (byName != 0) return byName;
        return (a.categoryId ?? '').compareTo(b.categoryId ?? '');
      });

    accounts.sort((a, b) {
      final byName = a.accountName.compareTo(b.accountName);
      if (byName != 0) return byName;
      return a.accountId.compareTo(b.accountId);
    });

    return MonthlyReport(
      monthStart: DateTime(monthStart.year, monthStart.month),
      baseCurrency: baseCurrency,
      incomeMinorByCurrency: income,
      expenseMinorByCurrency: expense,
      categories: categories,
      accountBalances: accounts,
    );
  }
}

final class _CategoryBuilder {
  _CategoryBuilder({
    required this.categoryId,
    required this.categoryName,
  });

  final String? categoryId;
  final String categoryName;
  BigInt plannedAmountMinor = BigInt.zero;
  final Map<String, BigInt> actual = {};
}

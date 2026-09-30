import '../../domain/models/period_report.dart';
import '../../domain/models/report_filter.dart';
import '../../domain/models/year_report.dart';
import '../../domain/repositories/extended_report_repository.dart';
import '../dal/report_dao.dart';

final class DriftExtendedReportRepository implements ExtendedReportRepository {
  const DriftExtendedReportRepository(this._reports);

  final ReportDao _reports;

  @override
  Stream<PeriodReport> watchPeriodReport(ReportFilter filter) {
    return _reports
        .watchPeriodReportRows(
          budgetId: filter.budgetId,
          fromInclusive: filter.fromInclusive,
          toExclusive: filter.toExclusive,
          categoryIds: filter.categoryIds,
          accountIds: filter.accountIds,
          authorIds: filter.authorIds,
        )
        .map(
          (rows) => _mapPeriodRows(
            rows,
            fromInclusive: filter.fromInclusive,
            toExclusive: filter.toExclusive,
          ),
        );
  }

  @override
  Stream<YearReport> watchYearReport({
    required String budgetId,
    required int year,
  }) {
    return _reports
        .watchYearReportRows(budgetId: budgetId, year: year)
        .map((rows) => _mapYearRows(rows, year));
  }

  PeriodReport _mapPeriodRows(
    List<PeriodReportRow> rows, {
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    final income = <String, BigInt>{};
    final expense = <String, BigInt>{};
    final categories = <String, _PeriodCategoryBuilder>{};

    for (final row in rows) {
      switch (row.kind) {
        case 'FLOW':
          final currency = row.currency!;
          if (row.keyId == 'INCOME') {
            income[currency] = row.amountMinor;
          } else if (row.keyId == 'EXPENSE') {
            expense[currency] = row.amountMinor;
          }
        case 'CATEGORY':
          final key = row.keyId ?? '';
          final builder = categories.putIfAbsent(
            key,
            () => _PeriodCategoryBuilder(
              categoryId: key.isEmpty ? null : key,
              categoryName: row.label ?? 'Без категории',
            ),
          );
          builder.actual[row.currency!] = row.amountMinor;
        default:
          throw StateError('Unsupported period report row: ${row.kind}');
      }
    }

    final categoryTotals =
        categories.values
            .map(
              (builder) => PeriodCategoryTotal(
                categoryId: builder.categoryId,
                categoryName: builder.categoryName,
                actualMinorByCurrency: builder.actual,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final byName = a.categoryName.compareTo(b.categoryName);
            if (byName != 0) return byName;
            return (a.categoryId ?? '').compareTo(b.categoryId ?? '');
          });

    return PeriodReport(
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
      incomeMinorByCurrency: income,
      expenseMinorByCurrency: expense,
      categories: categoryTotals,
    );
  }

  YearReport _mapYearRows(List<YearReportRow> rows, int year) {
    YearReportRow? baseRow;
    for (final row in rows) {
      if (row.kind == 'BASE') {
        baseRow = row;
        break;
      }
    }
    if (baseRow == null || baseRow.currency == null) {
      throw StateError('Budget base currency is missing for year report.');
    }
    final baseCurrency = baseRow.currency!;

    final monthBuilders = {
      for (var month = 1; month <= 12; month++)
        month: _YearMonthBuilder(monthStart: DateTime(year, month)),
    };
    final categoryBuilders = <String, _YearCategoryBuilder>{};

    for (final row in rows) {
      switch (row.kind) {
        case 'BASE':
          break;
        case 'MONTH_FLOW':
          final builder = monthBuilders[row.monthNumber];
          if (builder == null) {
            throw StateError('Invalid report month: ${row.monthNumber}');
          }
          final currency = row.currency!;
          if (row.keyId == 'INCOME') {
            builder.income[currency] = row.amountMinor;
          } else if (row.keyId == 'EXPENSE') {
            builder.expense[currency] = row.amountMinor;
          }
        case 'MONTH_PLAN':
          monthBuilders[row.monthNumber]!.plannedAmountMinor = row.amountMinor;
        case 'MONTH_ACTUAL_BASE':
          monthBuilders[row.monthNumber]!.actualBaseCurrencyMinor =
              row.amountMinor;
        case 'CATEGORY_PLAN':
          final key = row.keyId!;
          final builder = categoryBuilders.putIfAbsent(
            key,
            () => _YearCategoryBuilder(
              categoryId: key,
              categoryName: row.label ?? 'Категория',
            ),
          );
          builder.plannedAmountMinor = row.amountMinor;
        case 'CATEGORY_ACTUAL':
          final key = row.keyId ?? '';
          final builder = categoryBuilders.putIfAbsent(
            key,
            () => _YearCategoryBuilder(
              categoryId: key.isEmpty ? null : key,
              categoryName: row.label ?? 'Без категории',
            ),
          );
          builder.actual[row.currency!] = row.amountMinor;
        default:
          throw StateError('Unsupported year report row: ${row.kind}');
      }
    }

    final months = monthBuilders.values
        .map(
          (builder) => YearMonthReport(
            monthStart: builder.monthStart,
            incomeMinorByCurrency: builder.income,
            expenseMinorByCurrency: builder.expense,
            plannedAmountMinor: builder.plannedAmountMinor,
            actualBaseCurrencyMinor: builder.actualBaseCurrencyMinor,
          ),
        )
        .toList(growable: false);

    final categories =
        categoryBuilders.values
            .map(
              (builder) => YearCategoryReport(
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

    return YearReport(
      year: year,
      baseCurrency: baseCurrency,
      months: months,
      categories: categories,
    );
  }
}

final class _PeriodCategoryBuilder {
  _PeriodCategoryBuilder({
    required this.categoryId,
    required this.categoryName,
  });

  final String? categoryId;
  final String categoryName;
  final Map<String, BigInt> actual = {};
}

final class _YearMonthBuilder {
  _YearMonthBuilder({required this.monthStart});

  final DateTime monthStart;
  final Map<String, BigInt> income = {};
  final Map<String, BigInt> expense = {};
  BigInt plannedAmountMinor = BigInt.zero;
  BigInt actualBaseCurrencyMinor = BigInt.zero;
}

final class _YearCategoryBuilder {
  _YearCategoryBuilder({required this.categoryId, required this.categoryName});

  final String? categoryId;
  final String categoryName;
  BigInt plannedAmountMinor = BigInt.zero;
  final Map<String, BigInt> actual = {};
}

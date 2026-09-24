import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class PeriodSummary {
  const PeriodSummary({required this.incomeMinor, required this.expenseMinor});

  final BigInt incomeMinor;
  final BigInt expenseMinor;

  BigInt get netMinor => incomeMinor - expenseMinor;
}

final class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.amountMinor});

  final String? categoryId;
  final BigInt amountMinor;
}

final class DashboardMetricTotal {
  const DashboardMetricTotal({
    required this.metric,
    required this.currency,
    required this.amountMinor,
  });

  final String metric;
  final String currency;
  final BigInt amountMinor;
}

final class ReportDao {
  ReportDao(this._db);

  final AppDatabase _db;

  Future<PeriodSummary> getPeriodSummary({
    required String budgetId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async {
    final income = await _sumForType(
      budgetId: budgetId,
      type: 'INCOME',
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
    );
    final expense = await _sumForType(
      budgetId: budgetId,
      type: 'EXPENSE',
      fromInclusive: fromInclusive,
      toExclusive: toExclusive,
    );

    return PeriodSummary(incomeMinor: income, expenseMinor: expense);
  }

  Stream<List<DashboardMetricTotal>> watchDashboardMetrics({
    required String budgetId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    const sql = '''
WITH flow AS (
  SELECT
    type AS metric,
    currency,
    SUM(amount_minor) AS total_minor
  FROM transactions
  WHERE budget_id = ?
    AND deleted_at IS NULL
    AND occurred_at >= ?
    AND occurred_at < ?
    AND type IN ('INCOME', 'EXPENSE')
  GROUP BY type, currency
),
account_balances AS (
  SELECT
    a.id,
    a.currency,
    a.opening_balance_minor +
      COALESCE(
        SUM(
          CASE
            WHEN t.type = 'INCOME' AND t.account_id = a.id
              THEN t.amount_minor
            WHEN t.type = 'EXPENSE' AND t.account_id = a.id
              THEN -t.amount_minor
            WHEN t.type = 'TRANSFER' AND t.account_id = a.id
              THEN -t.amount_minor
            WHEN t.type = 'TRANSFER' AND t.destination_account_id = a.id
              THEN t.amount_minor
            ELSE 0
          END
        ),
        0
      ) AS balance_minor
  FROM accounts a
  LEFT JOIN transactions t
    ON t.budget_id = a.budget_id
    AND t.deleted_at IS NULL
    AND (t.account_id = a.id OR t.destination_account_id = a.id)
  WHERE a.budget_id = ?
    AND a.is_archived = 0
  GROUP BY a.id, a.currency, a.opening_balance_minor
),
balance AS (
  SELECT
    'BALANCE' AS metric,
    currency,
    SUM(balance_minor) AS total_minor
  FROM account_balances
  GROUP BY currency
)
SELECT metric, currency, total_minor FROM flow
UNION ALL
SELECT metric, currency, total_minor FROM balance
''';

    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(budgetId),
            Variable.withDateTime(fromInclusive),
            Variable.withDateTime(toExclusive),
            Variable.withString(budgetId),
          ],
          readsFrom: {
            _db.budgetTransactions,
            _db.accounts,
          },
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => DashboardMetricTotal(
                  metric: row.read<String>('metric'),
                  currency: row.read<String>('currency'),
                  amountMinor: BigInt.from(row.read<int>('total_minor')),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<CategoryTotal>> watchExpenseTotalsByCategory({
    required String budgetId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    final transactions = _db.budgetTransactions;
    final total = transactions.amountMinor.sum();
    final query = _db.selectOnly(transactions)
      ..addColumns([transactions.categoryId, total])
      ..where(
        transactions.budgetId.equals(budgetId) &
            transactions.type.equals('EXPENSE') &
            transactions.occurredAt.isBiggerOrEqualValue(fromInclusive) &
            transactions.occurredAt.isSmallerThanValue(toExclusive) &
            transactions.deletedAt.isNull(),
      )
      ..groupBy([transactions.categoryId]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CategoryTotal(
              categoryId: row.read(transactions.categoryId),
              amountMinor: row.read(total) ?? BigInt.zero,
            ),
          )
          .toList(),
    );
  }

  Future<BigInt> _sumForType({
    required String budgetId,
    required String type,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async {
    final transactions = _db.budgetTransactions;
    final total = transactions.amountMinor.sum();
    final query = _db.selectOnly(transactions)
      ..addColumns([total])
      ..where(
        transactions.budgetId.equals(budgetId) &
            transactions.type.equals(type) &
            transactions.occurredAt.isBiggerOrEqualValue(fromInclusive) &
            transactions.occurredAt.isSmallerThanValue(toExclusive) &
            transactions.deletedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(total) ?? BigInt.zero;
  }
}

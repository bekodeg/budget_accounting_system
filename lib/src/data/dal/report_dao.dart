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

final class MonthlyReportRow {
  const MonthlyReportRow({
    required this.kind,
    required this.keyId,
    required this.label,
    required this.currency,
    required this.amountMinor,
    required this.flag,
  });

  final String kind;
  final String? keyId;
  final String? label;
  final String? currency;
  final BigInt amountMinor;
  final int flag;
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
          readsFrom: {_db.budgetTransactions, _db.accounts},
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

  Stream<List<MonthlyReportRow>> watchMonthlyReportRows({
    required String budgetId,
    required DateTime monthStart,
  }) {
    final normalizedMonth = DateTime(monthStart.year, monthStart.month);
    final nextMonth = DateTime(normalizedMonth.year, normalizedMonth.month + 1);

    const sql = '''
WITH budget_info AS (
  SELECT base_currency
  FROM budgets
  WHERE id = ?
  LIMIT 1
),
flow AS (
  SELECT
    type AS key_id,
    currency,
    SUM(amount_minor) AS amount_minor
  FROM transactions
  WHERE budget_id = ?
    AND deleted_at IS NULL
    AND occurred_at >= ?
    AND occurred_at < ?
    AND type IN ('INCOME', 'EXPENSE')
  GROUP BY type, currency
),
category_actual AS (
  SELECT
    t.category_id AS key_id,
    COALESCE(c.name, 'Без категории') AS label,
    t.currency AS currency,
    SUM(t.amount_minor) AS amount_minor
  FROM transactions t
  LEFT JOIN categories c
    ON c.id = t.category_id
    AND c.budget_id = t.budget_id
  WHERE t.budget_id = ?
    AND t.deleted_at IS NULL
    AND t.occurred_at >= ?
    AND t.occurred_at < ?
    AND t.type = 'EXPENSE'
  GROUP BY t.category_id, c.name, t.currency
),
category_plan AS (
  SELECT
    p.category_id AS key_id,
    c.name AS label,
    b.base_currency AS currency,
    p.planned_amount_minor AS amount_minor
  FROM plans p
  JOIN categories c
    ON c.id = p.category_id
    AND c.budget_id = p.budget_id
  JOIN budgets b
    ON b.id = p.budget_id
  WHERE p.budget_id = ?
    AND p.month = ?
),
account_balances AS (
  SELECT
    a.id AS key_id,
    a.name AS label,
    a.currency AS currency,
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
      ) AS amount_minor,
    CASE WHEN a.is_archived = 1 THEN 1 ELSE 0 END AS flag
  FROM accounts a
  LEFT JOIN transactions t
    ON t.budget_id = a.budget_id
    AND t.deleted_at IS NULL
    AND t.occurred_at < ?
    AND (t.account_id = a.id OR t.destination_account_id = a.id)
  WHERE a.budget_id = ?
  GROUP BY
    a.id,
    a.name,
    a.currency,
    a.opening_balance_minor,
    a.is_archived
)
SELECT
  'BASE' AS row_kind,
  NULL AS key_id,
  NULL AS label,
  base_currency AS currency,
  0 AS amount_minor,
  0 AS flag
FROM budget_info
UNION ALL
SELECT
  'FLOW',
  key_id,
  NULL,
  currency,
  amount_minor,
  0
FROM flow
UNION ALL
SELECT
  'CATEGORY_ACTUAL',
  key_id,
  label,
  currency,
  amount_minor,
  0
FROM category_actual
UNION ALL
SELECT
  'CATEGORY_PLAN',
  key_id,
  label,
  currency,
  amount_minor,
  0
FROM category_plan
UNION ALL
SELECT
  'ACCOUNT',
  key_id,
  label,
  currency,
  amount_minor,
  flag
FROM account_balances
''';

    return _db
        .customSelect(
          sql,
          variables: [
            Variable.withString(budgetId),
            Variable.withString(budgetId),
            Variable.withDateTime(normalizedMonth),
            Variable.withDateTime(nextMonth),
            Variable.withString(budgetId),
            Variable.withDateTime(normalizedMonth),
            Variable.withDateTime(nextMonth),
            Variable.withString(budgetId),
            Variable.withDateTime(normalizedMonth),
            Variable.withDateTime(nextMonth),
            Variable.withString(budgetId),
          ],
          readsFrom: {
            _db.budgets,
            _db.budgetTransactions,
            _db.categories,
            _db.plans,
            _db.accounts,
          },
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => MonthlyReportRow(
                  kind: row.read<String>('row_kind'),
                  keyId: row.readNullable<String>('key_id'),
                  label: row.readNullable<String>('label'),
                  currency: row.readNullable<String>('currency'),
                  amountMinor: BigInt.from(row.read<int>('amount_minor')),
                  flag: row.read<int>('flag'),
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

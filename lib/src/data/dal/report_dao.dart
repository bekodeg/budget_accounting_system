import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class PeriodSummary {
  const PeriodSummary({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final BigInt incomeMinor;
  final BigInt expenseMinor;

  BigInt get netMinor => incomeMinor - expenseMinor;
}

final class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.amountMinor,
  });

  final String? categoryId;
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

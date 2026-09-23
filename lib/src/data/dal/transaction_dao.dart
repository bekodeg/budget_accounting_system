import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class TransactionDao {
  TransactionDao(this._db);

  final AppDatabase _db;

  Future<void> upsert(BudgetTransactionsCompanion transaction) async {
    await _db.into(_db.budgetTransactions).insertOnConflictUpdate(transaction);
  }

  Future<BudgetTransaction?> findById(String id) {
    return (_db.select(
      _db.budgetTransactions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Stream<List<BudgetTransaction>> watchPeriod({
    required String budgetId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    return (_db.select(_db.budgetTransactions)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.occurredAt.isBiggerOrEqualValue(fromInclusive) &
                row.occurredAt.isSmallerThanValue(toExclusive) &
                row.deletedAt.isNull(),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .watch();
  }

  Future<int> softDelete({required String id, required DateTime deletedAt}) {
    return (_db.update(
      _db.budgetTransactions,
    )..where((row) => row.id.equals(id))).write(
      BudgetTransactionsCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }
}

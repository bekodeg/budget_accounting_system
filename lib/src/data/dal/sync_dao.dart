import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class SyncDao {
  SyncDao(this._db);

  final AppDatabase _db;

  Future<void> append(SyncOperationsCompanion operation) async {
    await _db.into(_db.syncOperations).insert(
          operation,
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<List<SyncOperation>> getOperationsAfter({
    required String budgetId,
    required BigInt logicalClock,
    int limit = 500,
  }) {
    return (_db.select(_db.syncOperations)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.logicalClock.isBiggerThanValue(logicalClock),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.logicalClock)])
          ..limit(limit))
        .get();
  }

  Future<BigInt> getMaxLogicalClock(String budgetId) async {
    final maxClock = _db.syncOperations.logicalClock.max();
    final query = _db.selectOnly(_db.syncOperations)
      ..addColumns([maxClock])
      ..where(_db.syncOperations.budgetId.equals(budgetId));

    final row = await query.getSingle();
    return row.read(maxClock) ?? BigInt.zero;
  }
}

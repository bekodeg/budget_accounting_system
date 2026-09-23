import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class PlanReceiptDao {
  PlanReceiptDao(this._db);

  final AppDatabase _db;

  Stream<List<Plan>> watchPlansForMonth({
    required String budgetId,
    required DateTime month,
  }) {
    final normalizedMonth = DateTime(month.year, month.month);

    return (_db.select(_db.plans)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.month.equals(normalizedMonth),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.categoryId)]))
        .watch();
  }

  Future<void> upsertPlan(PlansCompanion plan) async {
    await _db.into(_db.plans).insertOnConflictUpdate(plan);
  }

  Future<void> upsertReceipt(ReceiptsCompanion receipt) async {
    await _db.into(_db.receipts).insertOnConflictUpdate(receipt);
  }

  Future<Receipt?> findReceiptById(String id) {
    return (_db.select(
      _db.receipts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }
}

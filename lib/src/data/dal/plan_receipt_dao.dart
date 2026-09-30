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

  Future<void> setPlanAmount({
    required String id,
    required String budgetId,
    required DateTime month,
    required String categoryId,
    required BigInt plannedAmountMinor,
    required DateTime updatedAt,
  }) {
    final normalizedMonth = DateTime(month.year, month.month);

    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.plans)..where(
                (row) =>
                    row.budgetId.equals(budgetId) &
                    row.month.equals(normalizedMonth) &
                    row.categoryId.equals(categoryId),
              ))
              .getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.plans)
            .insert(
              PlansCompanion.insert(
                id: id,
                budgetId: budgetId,
                month: normalizedMonth,
                categoryId: categoryId,
                plannedAmountMinor: plannedAmountMinor,
                updatedAt: Value(updatedAt),
              ),
            );
        return;
      }

      await (_db.update(
        _db.plans,
      )..where((row) => row.id.equals(existing.id))).write(
        PlansCompanion(
          plannedAmountMinor: Value(plannedAmountMinor),
          updatedAt: Value(updatedAt),
        ),
      );
    });
  }

  Future<void> clearPlan({
    required String budgetId,
    required DateTime month,
    required String categoryId,
  }) async {
    final normalizedMonth = DateTime(month.year, month.month);

    await (_db.delete(_db.plans)..where(
          (row) =>
              row.budgetId.equals(budgetId) &
              row.month.equals(normalizedMonth) &
              row.categoryId.equals(categoryId),
        ))
        .go();
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

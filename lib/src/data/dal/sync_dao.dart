import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class SyncDao {
  SyncDao(this._db);

  final AppDatabase _db;

  Future<void> append(SyncOperationsCompanion operation) async {
    await _db
        .into(_db.syncOperations)
        .insert(operation, mode: InsertMode.insertOrIgnore);
  }

  Future<void> appendStrict(SyncOperationsCompanion operation) async {
    await _db.into(_db.syncOperations).insert(operation);
  }

  Future<SyncOperation?> findById(String operationId) {
    return (_db.select(
      _db.syncOperations,
    )..where((row) => row.opId.equals(operationId))).getSingleOrNull();
  }

  Future<List<SyncOperation>> getEntityOperations({
    required String budgetId,
    required String entityType,
    required String entityId,
  }) {
    return (_db.select(_db.syncOperations)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.logicalClock),
            (row) => OrderingTerm.asc(row.deviceId),
            (row) => OrderingTerm.asc(row.opId),
          ]))
        .get();
  }

  Future<List<SyncOperation>> getAllOperationsForBudget(
    String budgetId,
  ) {
    return (_db.select(_db.syncOperations)
          ..where((row) => row.budgetId.equals(budgetId))
          ..orderBy([
            (row) => OrderingTerm.asc(row.logicalClock),
            (row) => OrderingTerm.asc(row.deviceId),
            (row) => OrderingTerm.asc(row.opId),
          ]))
        .get();
  }

  Future<List<SyncOperation>> getCheckpointOperations(String budgetId) async {
    final vector = await getStateVector(budgetId);
    final result = <SyncOperation>[];

    for (final entry in vector.entries) {
      final row = await (_db.select(_db.syncOperations)
            ..where(
              (item) =>
                  item.budgetId.equals(budgetId) &
                  item.deviceId.equals(entry.key) &
                  item.logicalClock.equals(entry.value),
            )
            ..orderBy([(item) => OrderingTerm.asc(item.opId)])
            ..limit(1))
          .getSingleOrNull();
      if (row != null) result.add(row);
    }

    return result;
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


  Future<Map<String, BigInt>> getStateVector(String budgetId) async {
    final maxClock = _db.syncOperations.logicalClock.max();
    final query = _db.selectOnly(_db.syncOperations)
      ..addColumns([_db.syncOperations.deviceId, maxClock])
      ..where(_db.syncOperations.budgetId.equals(budgetId))
      ..groupBy([_db.syncOperations.deviceId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(_db.syncOperations.deviceId)!:
            row.read(maxClock) ?? BigInt.zero,
    };
  }

  Future<List<SyncOperation>> getDeviceOperationsAfter({
    required String budgetId,
    required String deviceId,
    required BigInt logicalClock,
    required int limit,
  }) {
    return (_db.select(_db.syncOperations)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.deviceId.equals(deviceId) &
                row.logicalClock.isBiggerThanValue(logicalClock),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.logicalClock),
            (row) => OrderingTerm.asc(row.opId),
          ])
          ..limit(limit))
        .get();
  }

  Future<BigInt> getMaxLogicalClockForDevice(String deviceId) async {
    final maxClock = _db.syncOperations.logicalClock.max();
    final query = _db.selectOnly(_db.syncOperations)
      ..addColumns([maxClock])
      ..where(_db.syncOperations.deviceId.equals(deviceId));

    final row = await query.getSingle();
    return row.read(maxClock) ?? BigInt.zero;
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

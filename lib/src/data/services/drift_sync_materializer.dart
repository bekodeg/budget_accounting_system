import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/services/sync_merge_engine.dart';
import '../../domain/models/sync_mutation.dart';
import '../dal/sync_dao.dart';
import '../database/app_database.dart';

final class SyncEntityRef {
  const SyncEntityRef(this.entityType, this.entityId);

  final String entityType;
  final String entityId;

  @override
  bool operator ==(Object other) =>
      other is SyncEntityRef &&
      other.entityType == entityType &&
      other.entityId == entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);
}

final class DriftSyncMaterializer {
  const DriftSyncMaterializer({
    required AppDatabase database,
    required SyncDao syncDao,
    SyncMergeEngine mergeEngine = const SyncMergeEngine(),
  }) : _database = database,
       _syncDao = syncDao,
       _mergeEngine = mergeEngine;

  final AppDatabase _database;
  final SyncDao _syncDao;
  final SyncMergeEngine _mergeEngine;

  Future<void> materialize({
    required String budgetId,
    required Set<SyncEntityRef> entities,
  }) async {
    for (final entity in entities) {
      final rows = await _syncDao.getEntityOperations(
        budgetId: budgetId,
        entityType: entity.entityType,
        entityId: entity.entityId,
      );
      if (rows.isEmpty) continue;

      final operations = rows.map(_toDomain).toList(growable: false);
      final state = _mergeEngine.merge(operations);
      final values = state.values;

      switch (entity.entityType) {
        case 'category':
          if (!state.isDeleted) {
            await _database.into(_database.categories).insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: entity.entityId,
                budgetId: budgetId,
                name: _string(values, 'name'),
                kind: _string(values, 'kind'),
                isArchived: Value(_bool(values, 'is_archived', fallback: false)),
              ),
            );
          }
        case 'account':
          if (!state.isDeleted) {
            await _database.into(_database.accounts).insertOnConflictUpdate(
              AccountsCompanion.insert(
                id: entity.entityId,
                budgetId: budgetId,
                name: _string(values, 'name'),
                currency: _string(values, 'currency'),
                openingBalanceMinor: Value(
                  BigInt.parse(_string(values, 'opening_balance_minor')),
                ),
                isArchived: Value(_bool(values, 'is_archived', fallback: false)),
              ),
            );
          }
        case 'transaction':
          if (state.isDeleted) {
            final deletedAt = _winningDeleteTime(rows);
            await (_database.update(_database.budgetTransactions)
                  ..where(
                    (row) =>
                        row.id.equals(entity.entityId) &
                        row.budgetId.equals(budgetId),
                  ))
                .write(
                  BudgetTransactionsCompanion(
                    deletedAt: Value(deletedAt),
                    updatedAt: Value(deletedAt),
                  ),
                );
          } else {
            await _database
                .into(_database.budgetTransactions)
                .insertOnConflictUpdate(
                  BudgetTransactionsCompanion.insert(
                    id: entity.entityId,
                    budgetId: budgetId,
                    occurredAt: DateTime.parse(_string(values, 'occurred_at')),
                    amountMinor: BigInt.parse(_string(values, 'amount_minor')),
                    currency: _string(values, 'currency'),
                    type: _string(values, 'type'),
                    authorId: _string(values, 'author_id'),
                    accountId: _string(values, 'account_id'),
                    destinationAccountId: Value(
                      values['destination_account_id'] as String?,
                    ),
                    categoryId: Value(values['category_id'] as String?),
                    description: Value(values['description'] as String?),
                    createdAt: Value(
                      DateTime.parse(_string(values, 'created_at')),
                    ),
                    updatedAt: Value(
                      DateTime.parse(_string(values, 'updated_at')),
                    ),
                  ),
                );
          }
        case 'plan':
          final month = DateTime.parse(_string(values, 'month'));
          final categoryId = _string(values, 'category_id');
          if (state.isDeleted) {
            await (_database.delete(_database.plans)
                  ..where(
                    (row) =>
                        row.budgetId.equals(budgetId) &
                        row.month.equals(month) &
                        row.categoryId.equals(categoryId),
                  ))
                .go();
          } else {
            await _database.into(_database.plans).insertOnConflictUpdate(
              PlansCompanion.insert(
                id: entity.entityId,
                budgetId: budgetId,
                month: month,
                categoryId: categoryId,
                plannedAmountMinor: BigInt.parse(
                  _string(values, 'planned_amount_minor'),
                ),
                updatedAt: Value(
                  DateTime.parse(_string(values, 'updated_at')),
                ),
              ),
            );
          }
        case 'budget_member':
          final separator = entity.entityId.indexOf(':');
          final userId = separator < 0
              ? entity.entityId
              : entity.entityId.substring(separator + 1);
          final role = values['role'];
          if (role is String) {
            await (_database.update(_database.budgetMembers)
                  ..where(
                    (row) =>
                        row.budgetId.equals(budgetId) &
                        row.userId.equals(userId),
                  ))
                .write(BudgetMembersCompanion(role: Value(role)));
          }
      }
    }
  }

  SignedSyncOperation _toDomain(SyncOperation row) {
    return SignedSyncOperation(
      operationId: row.opId,
      budgetId: row.budgetId,
      entityType: row.entityType,
      entityId: row.entityId,
      type: switch (row.opType) {
        'CREATE' => SyncMutationType.create,
        'PATCH' => SyncMutationType.patch,
        'DELETE' => SyncMutationType.delete,
        _ => throw StateError('Unsupported sync op type: ${row.opType}'),
      },
      patchJson: row.patch,
      authorId: row.authorId,
      deviceId: row.deviceId,
      logicalClock: row.logicalClock,
      createdAt: row.createdAt,
    );
  }
}

String _string(Map<String, Object?> values, String key) {
  final value = values[key];
  if (value is! String || value.isEmpty) {
    throw StateError('Missing materialized field: $key');
  }
  return value;
}

bool _bool(
  Map<String, Object?> values,
  String key, {
  required bool fallback,
}) {
  final value = values[key];
  return value is bool ? value : fallback;
}

DateTime _winningDeleteTime(List<SyncOperation> rows) {
  final deletes = rows.where((row) => row.opType == 'DELETE').toList()
    ..sort((a, b) {
      final clock = a.logicalClock.compareTo(b.logicalClock);
      if (clock != 0) return clock;
      return a.deviceId.compareTo(b.deviceId);
    });
  if (deletes.isEmpty) return DateTime.now().toUtc();
  return deletes.last.createdAt;
}

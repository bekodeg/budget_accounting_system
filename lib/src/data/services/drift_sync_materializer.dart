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
          await _materializeCategory(
            budgetId: budgetId,
            entityId: entity.entityId,
            values: values,
            deleted: state.isDeleted,
          );
        case 'account':
          await _materializeAccount(
            budgetId: budgetId,
            entityId: entity.entityId,
            values: values,
            deleted: state.isDeleted,
          );
        case 'transaction':
          await _materializeTransaction(
            budgetId: budgetId,
            entityId: entity.entityId,
            values: values,
            rows: rows,
            deleted: state.isDeleted,
          );
        case 'plan':
          await _materializePlan(
            budgetId: budgetId,
            entityId: entity.entityId,
            values: values,
            deleted: state.isDeleted,
          );
        case 'budget_member':
          await _materializeMember(
            budgetId: budgetId,
            entityId: entity.entityId,
            values: values,
          );
      }
    }
  }

  Future<void> _materializeCategory({
    required String budgetId,
    required String entityId,
    required Map<String, Object?> values,
    required bool deleted,
  }) async {
    if (deleted) return;

    final existing =
        await (_database.select(_database.categories)..where(
              (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      final name = values['name'];
      final kind = values['kind'];
      if (name is! String || kind is! String) return;

      await _database
          .into(_database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: entityId,
              budgetId: budgetId,
              name: name,
              kind: kind,
              isArchived: Value(
                values['is_archived'] is bool
                    ? values['is_archived']! as bool
                    : false,
              ),
            ),
          );
      return;
    }

    await (_database.update(_database.categories)..where(
          (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
        ))
        .write(
          CategoriesCompanion(
            name: _stringValue(values['name']),
            kind: _stringValue(values['kind']),
            isArchived: _boolValue(values['is_archived']),
          ),
        );
  }

  Future<void> _materializeAccount({
    required String budgetId,
    required String entityId,
    required Map<String, Object?> values,
    required bool deleted,
  }) async {
    if (deleted) return;

    final existing =
        await (_database.select(_database.accounts)..where(
              (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      final name = values['name'];
      final currency = values['currency'];
      final opening = _bigInt(values['opening_balance_minor']);
      if (name is! String || currency is! String || opening == null) return;

      await _database
          .into(_database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: entityId,
              budgetId: budgetId,
              name: name,
              currency: currency,
              openingBalanceMinor: Value(opening),
              isArchived: Value(
                values['is_archived'] is bool
                    ? values['is_archived']! as bool
                    : false,
              ),
            ),
          );
      return;
    }

    await (_database.update(_database.accounts)..where(
          (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
        ))
        .write(
          AccountsCompanion(
            name: _stringValue(values['name']),
            currency: _stringValue(values['currency']),
            openingBalanceMinor: _bigIntValue(values['opening_balance_minor']),
            isArchived: _boolValue(values['is_archived']),
          ),
        );
  }

  Future<void> _materializeTransaction({
    required String budgetId,
    required String entityId,
    required Map<String, Object?> values,
    required List<SyncOperation> rows,
    required bool deleted,
  }) async {
    final existing =
        await (_database.select(_database.budgetTransactions)..where(
              (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
            ))
            .getSingleOrNull();

    if (deleted) {
      if (existing == null) return;
      final deletedAt = _winningDeleteTime(rows);
      await (_database.update(_database.budgetTransactions)..where(
            (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
          ))
          .write(
            BudgetTransactionsCompanion(
              deletedAt: Value(deletedAt),
              updatedAt: Value(deletedAt),
            ),
          );
      return;
    }

    if (existing == null) {
      final occurredAt = _dateTime(values['occurred_at']);
      final amountMinor = _bigInt(values['amount_minor']);
      final currency = values['currency'];
      final type = values['type'];
      final authorId = values['author_id'];
      final accountId = values['account_id'];
      final createdAt = _dateTime(values['created_at']);
      final updatedAt = _dateTime(values['updated_at']);
      if (occurredAt == null ||
          amountMinor == null ||
          currency is! String ||
          type is! String ||
          authorId is! String ||
          accountId is! String ||
          createdAt == null ||
          updatedAt == null) {
        return;
      }

      await _database
          .into(_database.budgetTransactions)
          .insert(
            BudgetTransactionsCompanion.insert(
              id: entityId,
              budgetId: budgetId,
              occurredAt: occurredAt,
              amountMinor: amountMinor,
              currency: currency,
              type: type,
              authorId: authorId,
              accountId: accountId,
              destinationAccountId: Value(
                values['destination_account_id'] as String?,
              ),
              categoryId: Value(values['category_id'] as String?),
              description: Value(values['description'] as String?),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );
      return;
    }

    await (_database.update(_database.budgetTransactions)..where(
          (row) => row.id.equals(entityId) & row.budgetId.equals(budgetId),
        ))
        .write(
          BudgetTransactionsCompanion(
            occurredAt: _dateTimeValue(values['occurred_at']),
            amountMinor: _bigIntValue(values['amount_minor']),
            currency: _stringValue(values['currency']),
            type: _stringValue(values['type']),
            authorId: _stringValue(values['author_id']),
            accountId: _stringValue(values['account_id']),
            destinationAccountId: values.containsKey('destination_account_id')
                ? Value(values['destination_account_id'] as String?)
                : const Value.absent(),
            categoryId: values.containsKey('category_id')
                ? Value(values['category_id'] as String?)
                : const Value.absent(),
            description: values.containsKey('description')
                ? Value(values['description'] as String?)
                : const Value.absent(),
            createdAt: _dateTimeValue(values['created_at']),
            updatedAt: _dateTimeValue(values['updated_at']),
          ),
        );
  }

  Future<void> _materializePlan({
    required String budgetId,
    required String entityId,
    required Map<String, Object?> values,
    required bool deleted,
  }) async {
    final month = _dateTime(values['month']);
    final categoryId = values['category_id'];
    if (month == null || categoryId is! String) return;

    if (deleted) {
      await (_database.delete(_database.plans)..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.month.equals(month) &
                row.categoryId.equals(categoryId),
          ))
          .go();
      return;
    }

    final amount = _bigInt(values['planned_amount_minor']);
    final updatedAt = _dateTime(values['updated_at']);
    if (amount == null || updatedAt == null) return;

    final existing =
        await (_database.select(_database.plans)..where(
              (row) =>
                  row.budgetId.equals(budgetId) &
                  row.month.equals(month) &
                  row.categoryId.equals(categoryId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _database
          .into(_database.plans)
          .insert(
            PlansCompanion.insert(
              id: entityId,
              budgetId: budgetId,
              month: month,
              categoryId: categoryId,
              plannedAmountMinor: amount,
              updatedAt: Value(updatedAt),
            ),
          );
      return;
    }

    await (_database.update(
      _database.plans,
    )..where((row) => row.id.equals(existing.id))).write(
      PlansCompanion(
        plannedAmountMinor: Value(amount),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> _materializeMember({
    required String budgetId,
    required String entityId,
    required Map<String, Object?> values,
  }) async {
    final separator = entityId.indexOf(':');
    final userId = separator < 0 ? entityId : entityId.substring(separator + 1);
    final role = values['role'];
    if (role is! String) return;

    await (_database.update(_database.budgetMembers)..where(
          (row) => row.budgetId.equals(budgetId) & row.userId.equals(userId),
        ))
        .write(BudgetMembersCompanion(role: Value(role)));
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

Value<String> _stringValue(Object? value) =>
    value is String ? Value(value) : const Value.absent();

Value<bool> _boolValue(Object? value) =>
    value is bool ? Value(value) : const Value.absent();

BigInt? _bigInt(Object? value) =>
    value is String ? BigInt.tryParse(value) : null;

Value<BigInt> _bigIntValue(Object? value) {
  final parsed = _bigInt(value);
  return parsed == null ? const Value.absent() : Value(parsed);
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Value<DateTime> _dateTimeValue(Object? value) {
  final parsed = _dateTime(value);
  return parsed == null ? const Value.absent() : Value(parsed);
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

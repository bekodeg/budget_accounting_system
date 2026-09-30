import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/errors/budget_snapshot_error.dart';
import '../../application/ports/budget_snapshot_repository.dart';
import '../../application/services/budget_snapshot_codec.dart';
import '../../application/services/sync_merge_engine.dart';
import '../../domain/models/budget_snapshot.dart';
import '../../domain/models/sync_mutation.dart';
import '../dal/sync_dao.dart';
import '../database/app_database.dart';

final class DriftBudgetSnapshotRepository implements BudgetSnapshotRepository {
  const DriftBudgetSnapshotRepository({
    required AppDatabase database,
    required SyncDao syncDao,
    BudgetSnapshotCodec codec = const BudgetSnapshotCodec(),
    SyncMergeEngine mergeEngine = const SyncMergeEngine(),
  }) : _database = database,
       _syncDao = syncDao,
       _codec = codec,
       _mergeEngine = mergeEngine;

  final AppDatabase _database;
  final SyncDao _syncDao;
  final BudgetSnapshotCodec _codec;
  final SyncMergeEngine _mergeEngine;

  @override
  Future<BudgetSnapshotPackage> create(String budgetId) {
    return _database.transaction(() async {
      final budget = await (_database.select(_database.budgets)
            ..where((row) => row.id.equals(budgetId)))
          .getSingleOrNull();
      if (budget == null) {
        throw StateError('Budget not found: $budgetId');
      }

      final members = await (_database.select(_database.budgetMembers)
            ..where((row) => row.budgetId.equals(budgetId)))
          .get();
      final userIds = members.map((row) => row.userId).toSet();
      final users = userIds.isEmpty
          ? <User>[]
          : await (_database.select(_database.users)
                ..where((row) => row.id.isIn(userIds)))
              .get();
      final devices = userIds.isEmpty
          ? <Device>[]
          : await (_database.select(_database.devices)
                ..where((row) => row.userId.isIn(userIds)))
              .get();
      final categories = await (_database.select(_database.categories)
            ..where((row) => row.budgetId.equals(budgetId)))
          .get();
      final accounts = await (_database.select(_database.accounts)
            ..where((row) => row.budgetId.equals(budgetId)))
          .get();
      final receipts = await (_database.select(_database.receipts)
            ..where((row) => row.budgetId.equals(budgetId)))
          .get();
      final transactions = await (_database.select(_database.budgetTransactions)
            ..where((row) => row.budgetId.equals(budgetId)))
          .get();
      final plans = await (_database.select(_database.plans)
            ..where((row) => row.budgetId.equals(budgetId)))
          .get();

      final allOperations = await _syncDao.getAllOperationsForBudget(budgetId);
      final checkpointOperations =
          await _syncDao.getCheckpointOperations(budgetId);
      final baseline = _compactBaseline(
        allOperations: allOperations,
        checkpointOperations: checkpointOperations,
      );

      final body = <String, Object?>{
        'v': BudgetSnapshotCodec.currentVersion,
        'db_schema': _database.schemaVersion,
        'budget_id': budgetId,
        'created_at': DateTime.now().toUtc(),
        'checkpoint': baseline.map(_syncOperationMap).toList(growable: false),
        'data': {
          'users': users.map(_userMap).toList(growable: false),
          'devices': devices.map(_deviceMap).toList(growable: false),
          'budget': _budgetMap(budget),
          'members': members.map(_memberMap).toList(growable: false),
          'categories': categories.map(_categoryMap).toList(growable: false),
          'accounts': accounts.map(_accountMap).toList(growable: false),
          'receipts': receipts.map(_receiptMap).toList(growable: false),
          'transactions': transactions
              .map(_transactionMap)
              .toList(growable: false),
          'plans': plans.map(_planMap).toList(growable: false),
        },
      };

      return _codec.encode(body);
    });
  }

  @override
  Future<void> apply({
    required String expectedBudgetId,
    required BudgetSnapshotPackage snapshot,
  }) async {
    final decoded = await _codec.decodeAndVerify(
      expectedBudgetId: expectedBudgetId,
      snapshot: snapshot,
    );
    final body = decoded.body;
    final dbSchema = body['db_schema'];
    if (dbSchema != _database.schemaVersion) {
      throw BudgetSnapshotError(
        BudgetSnapshotErrorCode.unsupportedVersion,
        'Snapshot DB schema $dbSchema is incompatible with local schema ' +
            _database.schemaVersion.toString() +
            '.',
      );
    }

    final data = _map(body, 'data');
    final budget = _map(data, 'budget');
    _requireBudget(budget, expectedBudgetId);

    final users = _maps(data, 'users');
    final devices = _maps(data, 'devices');
    final members = _maps(data, 'members');
    final categories = _maps(data, 'categories');
    final accounts = _maps(data, 'accounts');
    final receipts = _maps(data, 'receipts');
    final transactions = _maps(data, 'transactions');
    final plans = _maps(data, 'plans');
    final checkpoint = _maps(body, 'checkpoint');

    for (final row in members) {
      _requireBudget(row, expectedBudgetId);
    }
    for (final row in categories) {
      _requireBudget(row, expectedBudgetId);
    }
    for (final row in accounts) {
      _requireBudget(row, expectedBudgetId);
    }
    for (final row in receipts) {
      _requireBudget(row, expectedBudgetId);
    }
    for (final row in transactions) {
      _requireBudget(row, expectedBudgetId);
    }
    for (final row in plans) {
      _requireBudget(row, expectedBudgetId);
    }
    for (final row in checkpoint) {
      _requireBudget(row, expectedBudgetId);
    }

    await _database.transaction(() async {
      for (final row in users) {
        await _database.into(_database.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: _string(row, 'id'),
            name: _string(row, 'name'),
            publicKey: _string(row, 'public_key'),
            createdAt: Value(_date(row, 'created_at')),
          ),
        );
      }

      for (final row in devices) {
        await _database.into(_database.devices).insertOnConflictUpdate(
          DevicesCompanion.insert(
            id: _string(row, 'id'),
            userId: _string(row, 'user_id'),
            name: Value(_nullableString(row, 'name')),
            createdAt: Value(_date(row, 'created_at')),
            revokedAt: Value(_nullableDate(row, 'revoked_at')),
          ),
        );
      }

      await _database.into(_database.budgets).insertOnConflictUpdate(
        BudgetsCompanion.insert(
          id: _string(budget, 'id'),
          name: _string(budget, 'name'),
          baseCurrency: _string(budget, 'base_currency'),
          createdBy: _string(budget, 'created_by'),
          createdAt: Value(_date(budget, 'created_at')),
        ),
      );

      for (final row in members) {
        await _database.into(_database.budgetMembers).insertOnConflictUpdate(
          BudgetMembersCompanion.insert(
            budgetId: expectedBudgetId,
            userId: _string(row, 'user_id'),
            role: _string(row, 'role'),
            joinedAt: Value(_date(row, 'joined_at')),
            revokedAt: Value(_nullableDate(row, 'revoked_at')),
          ),
        );
      }

      for (final row in categories) {
        await _database.into(_database.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: _string(row, 'id'),
            budgetId: expectedBudgetId,
            name: _string(row, 'name'),
            kind: _string(row, 'kind'),
            isArchived: Value(_bool(row, 'is_archived')),
          ),
        );
      }

      for (final row in accounts) {
        await _database.into(_database.accounts).insertOnConflictUpdate(
          AccountsCompanion.insert(
            id: _string(row, 'id'),
            budgetId: expectedBudgetId,
            name: _string(row, 'name'),
            openingBalanceMinor: Value(
              BigInt.parse(_string(row, 'opening_balance_minor')),
            ),
            currency: _string(row, 'currency'),
            isArchived: Value(_bool(row, 'is_archived')),
          ),
        );
      }

      for (final row in receipts) {
        await _database.into(_database.receipts).insertOnConflictUpdate(
          ReceiptsCompanion.insert(
            id: _string(row, 'id'),
            budgetId: expectedBudgetId,
            rawQr: Value(_nullableString(row, 'raw_qr')),
            imagePath: Value(_nullableString(row, 'image_path')),
            merchant: Value(_nullableString(row, 'merchant')),
            receiptTime: Value(_nullableDate(row, 'receipt_time')),
            totalMinor: Value(_nullableBigInt(row, 'total_minor')),
            parsedPayload: Value(_nullableString(row, 'parsed_payload')),
            parseStatus: Value(_string(row, 'parse_status')),
          ),
        );
      }

      for (final row in transactions) {
        await _database
            .into(_database.budgetTransactions)
            .insertOnConflictUpdate(
              BudgetTransactionsCompanion.insert(
                id: _string(row, 'id'),
                budgetId: expectedBudgetId,
                occurredAt: _date(row, 'occurred_at'),
                amountMinor: BigInt.parse(_string(row, 'amount_minor')),
                currency: _string(row, 'currency'),
                type: _string(row, 'type'),
                authorId: _string(row, 'author_id'),
                accountId: _string(row, 'account_id'),
                destinationAccountId: Value(
                  _nullableString(row, 'destination_account_id'),
                ),
                description: Value(_nullableString(row, 'description')),
                categoryId: Value(_nullableString(row, 'category_id')),
                receiptId: Value(_nullableString(row, 'receipt_id')),
                createdAt: Value(_date(row, 'created_at')),
                updatedAt: Value(_date(row, 'updated_at')),
                deletedAt: Value(_nullableDate(row, 'deleted_at')),
              ),
            );
      }

      for (final row in plans) {
        await _database.into(_database.plans).insertOnConflictUpdate(
          PlansCompanion.insert(
            id: _string(row, 'id'),
            budgetId: expectedBudgetId,
            month: _date(row, 'month'),
            categoryId: _string(row, 'category_id'),
            plannedAmountMinor: BigInt.parse(
              _string(row, 'planned_amount_minor'),
            ),
            updatedAt: Value(_date(row, 'updated_at')),
          ),
        );
      }

      for (final row in checkpoint) {
        await _database.into(_database.syncOperations).insert(
          SyncOperationsCompanion.insert(
            opId: _string(row, 'op_id'),
            budgetId: expectedBudgetId,
            entityType: _string(row, 'entity_type'),
            entityId: _string(row, 'entity_id'),
            opType: _string(row, 'op_type'),
            patch: _string(row, 'patch'),
            authorId: _string(row, 'author_id'),
            deviceId: _string(row, 'device_id'),
            logicalClock: BigInt.parse(_string(row, 'logical_clock')),
            signature: base64Url.decode(_string(row, 'signature')),
            createdAt: Value(_date(row, 'created_at')),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  List<SyncOperation> _compactBaseline({
    required List<SyncOperation> allOperations,
    required List<SyncOperation> checkpointOperations,
  }) {
    final grouped = <String, List<SyncOperation>>{};
    for (final row in allOperations) {
      grouped
          .putIfAbsent(row.entityType + '\u0000' + row.entityId, () => [])
          .add(row);
    }

    final keep = <String>{};
    for (final rows in grouped.values) {
      final state = _mergeEngine.merge(rows.map(_toDomain));
      for (final field in state.fields.values) {
        keep.add(field.operationId);
      }
      final tombstone = state.tombstoneVersion;
      if (tombstone != null) {
        for (final row in rows) {
          if (row.opType == 'DELETE' &&
              row.logicalClock == tombstone.logicalClock &&
              row.deviceId == tombstone.deviceId) {
            keep.add(row.opId);
          }
        }
      }
    }
    keep.addAll(checkpointOperations.map((row) => row.opId));

    final byId = {for (final row in allOperations) row.opId: row};
    final result = [
      for (final id in keep)
        if (byId[id] != null) byId[id]!,
    ];
    result.sort((a, b) {
      final clock = a.logicalClock.compareTo(b.logicalClock);
      if (clock != 0) return clock;
      final device = a.deviceId.compareTo(b.deviceId);
      if (device != 0) return device;
      return a.opId.compareTo(b.opId);
    });
    return result;
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
        _ => throw StateError('Unsupported sync op type: ' + row.opType),
      },
      patchJson: row.patch,
      authorId: row.authorId,
      deviceId: row.deviceId,
      logicalClock: row.logicalClock,
      createdAt: row.createdAt,
    );
  }
}

Map<String, Object?> _userMap(User row) => {
  'id': row.id,
  'name': row.name,
  'public_key': row.publicKey,
  'created_at': row.createdAt,
};

Map<String, Object?> _deviceMap(Device row) => {
  'id': row.id,
  'user_id': row.userId,
  'name': row.name,
  'created_at': row.createdAt,
  'revoked_at': row.revokedAt,
};

Map<String, Object?> _budgetMap(Budget row) => {
  'id': row.id,
  'budget_id': row.id,
  'name': row.name,
  'base_currency': row.baseCurrency,
  'created_by': row.createdBy,
  'created_at': row.createdAt,
};

Map<String, Object?> _memberMap(BudgetMember row) => {
  'budget_id': row.budgetId,
  'user_id': row.userId,
  'role': row.role,
  'joined_at': row.joinedAt,
  'revoked_at': row.revokedAt,
};

Map<String, Object?> _categoryMap(Category row) => {
  'id': row.id,
  'budget_id': row.budgetId,
  'name': row.name,
  'kind': row.kind,
  'is_archived': row.isArchived,
};

Map<String, Object?> _accountMap(Account row) => {
  'id': row.id,
  'budget_id': row.budgetId,
  'name': row.name,
  'opening_balance_minor': row.openingBalanceMinor,
  'currency': row.currency,
  'is_archived': row.isArchived,
};

Map<String, Object?> _receiptMap(Receipt row) => {
  'id': row.id,
  'budget_id': row.budgetId,
  'raw_qr': row.rawQr,
  'image_path': row.imagePath,
  'merchant': row.merchant,
  'receipt_time': row.receiptTime,
  'total_minor': row.totalMinor,
  'parsed_payload': row.parsedPayload,
  'parse_status': row.parseStatus,
};

Map<String, Object?> _transactionMap(BudgetTransaction row) => {
  'id': row.id,
  'budget_id': row.budgetId,
  'occurred_at': row.occurredAt,
  'amount_minor': row.amountMinor,
  'currency': row.currency,
  'type': row.type,
  'author_id': row.authorId,
  'account_id': row.accountId,
  'destination_account_id': row.destinationAccountId,
  'description': row.description,
  'category_id': row.categoryId,
  'receipt_id': row.receiptId,
  'created_at': row.createdAt,
  'updated_at': row.updatedAt,
  'deleted_at': row.deletedAt,
};

Map<String, Object?> _planMap(Plan row) => {
  'id': row.id,
  'budget_id': row.budgetId,
  'month': row.month,
  'category_id': row.categoryId,
  'planned_amount_minor': row.plannedAmountMinor,
  'updated_at': row.updatedAt,
};

Map<String, Object?> _syncOperationMap(SyncOperation row) => {
  'op_id': row.opId,
  'budget_id': row.budgetId,
  'entity_type': row.entityType,
  'entity_id': row.entityId,
  'op_type': row.opType,
  'patch': row.patch,
  'author_id': row.authorId,
  'device_id': row.deviceId,
  'logical_clock': row.logicalClock,
  'signature': base64Url.encode(row.signature),
  'created_at': row.createdAt,
};

Map<String, dynamic> _map(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! Map<String, dynamic>) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be an object.',
    );
  }
  return result;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! List) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be an array.',
    );
  }
  return result.map((item) {
    if (item is! Map<String, dynamic>) {
      throw BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot array $key contains a non-object value.',
      );
    }
    return item;
  }).toList(growable: false);
}

void _requireBudget(Map<String, dynamic> row, String expectedBudgetId) {
  if (_string(row, 'budget_id') != expectedBudgetId) {
    throw const BudgetSnapshotError(
      BudgetSnapshotErrorCode.budgetMismatch,
      'Snapshot row belongs to another budget.',
    );
  }
}

String _string(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be a non-empty string.',
    );
  }
  return value;
}

String? _nullableString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is! String) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be a string or null.',
    );
  }
  return value;
}

bool _bool(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! bool) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be boolean.',
    );
  }
  return value;
}

DateTime _date(Map<String, dynamic> row, String key) {
  final value = row[key];
  final result = value is String ? DateTime.tryParse(value) : null;
  if (result == null) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be an ISO-8601 timestamp.',
    );
  }
  return result.toUtc();
}

DateTime? _nullableDate(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  final result = value is String ? DateTime.tryParse(value) : null;
  if (result == null) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be an ISO-8601 timestamp or null.',
    );
  }
  return result.toUtc();
}

BigInt? _nullableBigInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  final result = value is String ? BigInt.tryParse(value) : null;
  if (result == null) {
    throw BudgetSnapshotError(
      BudgetSnapshotErrorCode.invalidFormat,
      'Snapshot field $key must be an integer string or null.',
    );
  }
  return result;
}

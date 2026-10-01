import 'dart:convert';

import '../../application/errors/budget_backup_error.dart';
import '../../application/ports/budget_backup_repository.dart';
import '../../application/ports/budget_snapshot_repository.dart';
import '../../application/ports/id_generator.dart';
import '../../application/services/budget_backup_codec.dart';
import '../../application/services/budget_snapshot_codec.dart';
import '../../domain/models/budget_backup.dart';
import '../../domain/models/budget_snapshot.dart';
import '../database/app_database.dart';

final class DriftBudgetBackupRepository implements BudgetBackupRepository {
  DriftBudgetBackupRepository({
    required AppDatabase database,
    required BudgetSnapshotRepository snapshotRepository,
    required IdGenerator idGenerator,
    BudgetBackupCodec? backupCodec,
    BudgetSnapshotCodec snapshotCodec = const BudgetSnapshotCodec(),
  }) : _database = database,
       _snapshotRepository = snapshotRepository,
       _idGenerator = idGenerator,
       _backupCodec = backupCodec ?? BudgetBackupCodec(),
       _snapshotCodec = snapshotCodec;

  final AppDatabase _database;
  final BudgetSnapshotRepository _snapshotRepository;
  final IdGenerator _idGenerator;
  final BudgetBackupCodec _backupCodec;
  final BudgetSnapshotCodec _snapshotCodec;

  @override
  Future<String> createEncrypted({
    required String budgetId,
    required String password,
  }) async {
    final snapshot = await _snapshotRepository.create(budgetId);
    return _backupCodec.encrypt(
      password: password,
      sourceBudgetId: budgetId,
      snapshot: snapshot,
    );
  }

  @override
  Future<BudgetBackupPreview> preview({
    required String payload,
    required String password,
  }) async {
    final decoded = await _decodeValidated(payload: payload, password: password);
    return _previewFromBody(
      formatVersion: BudgetBackupCodec.currentVersion,
      createdAt: decoded.backup.createdAt,
      body: decoded.snapshot.body,
    );
  }

  @override
  Future<BudgetBackupRestoreResult> restore({
    required String payload,
    required String password,
  }) async {
    final decoded = await _decodeValidated(payload: payload, password: password);
    final sourceBudgetId = decoded.backup.sourceBudgetId;
    final body = decoded.snapshot.body;
    await _validateIdentityConflicts(body);

    final existing = await (_database.select(
      _database.budgets,
    )..where((row) => row.id.equals(sourceBudgetId))).getSingleOrNull();

    if (existing == null) {
      await _snapshotRepository.apply(
        expectedBudgetId: sourceBudgetId,
        snapshot: decoded.backup.snapshot,
      );
      return BudgetBackupRestoreResult(
        budgetId: sourceBudgetId,
        restoredAsNewBudget: false,
      );
    }

    final cloned = _cloneAsNewBudget(body);
    final package = await _snapshotCodec.encode(cloned.body);
    await _snapshotRepository.apply(
      expectedBudgetId: cloned.budgetId,
      snapshot: package,
    );
    return BudgetBackupRestoreResult(
      budgetId: cloned.budgetId,
      restoredAsNewBudget: true,
    );
  }

  Future<_ValidatedBackup> _decodeValidated({
    required String payload,
    required String password,
  }) async {
    final backup = await _backupCodec.decrypt(
      password: password,
      payload: payload,
    );
    try {
      final snapshot = await _snapshotCodec.decodeAndVerify(
        expectedBudgetId: backup.sourceBudgetId,
        snapshot: backup.snapshot,
      );
      return _ValidatedBackup(backup: backup, snapshot: snapshot);
    } on Object catch (error) {
      throw BudgetBackupError(
        BudgetBackupErrorCode.invalidSnapshot,
        'Backup содержит некорректный snapshot: $error',
      );
    }
  }

  Future<void> _validateIdentityConflicts(Map<String, dynamic> body) async {
    final data = _map(body, 'data');
    for (final user in _maps(data, 'users')) {
      final id = _string(user, 'id');
      final existing = await (_database.select(
        _database.users,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing != null &&
          existing.publicKey != _string(user, 'public_key')) {
        throw const BudgetBackupError(
          BudgetBackupErrorCode.invalidSnapshot,
          'Backup конфликтует с локальной публичной identity.',
        );
      }
    }

    for (final device in _maps(data, 'devices')) {
      final id = _string(device, 'id');
      final existing = await (_database.select(
        _database.devices,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing != null &&
          existing.userId != _string(device, 'user_id')) {
        throw const BudgetBackupError(
          BudgetBackupErrorCode.invalidSnapshot,
          'Backup конфликтует с локальной device identity.',
        );
      }
    }
  }

  _ClonedSnapshot _cloneAsNewBudget(Map<String, dynamic> original) {
    final body = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    final data = _map(body, 'data');
    final budget = _map(data, 'budget');
    final sourceBudgetId = _string(body, 'budget_id');
    final newBudgetId = _idGenerator.nextId();

    final categoryIds = _idMap(_maps(data, 'categories'));
    final accountIds = _idMap(_maps(data, 'accounts'));
    final receiptIds = _idMap(_maps(data, 'receipts'));
    final transactionIds = _idMap(_maps(data, 'transactions'));
    final planIds = _idMap(_maps(data, 'plans'));

    body['budget_id'] = newBudgetId;
    body['created_at'] = DateTime.now().toUtc().toIso8601String();
    body['checkpoint'] = <Object?>[];

    budget['id'] = newBudgetId;
    budget['budget_id'] = newBudgetId;
    budget['name'] = '${_string(budget, 'name')} (восстановлено)';

    for (final row in _maps(data, 'members')) {
      row['budget_id'] = newBudgetId;
    }
    for (final row in _maps(data, 'categories')) {
      row['budget_id'] = newBudgetId;
      row['id'] = categoryIds[_string(row, 'id')];
    }
    for (final row in _maps(data, 'accounts')) {
      row['budget_id'] = newBudgetId;
      row['id'] = accountIds[_string(row, 'id')];
    }
    for (final row in _maps(data, 'receipts')) {
      row['budget_id'] = newBudgetId;
      row['id'] = receiptIds[_string(row, 'id')];
    }
    for (final row in _maps(data, 'transactions')) {
      row['budget_id'] = newBudgetId;
      row['id'] = transactionIds[_string(row, 'id')];
      row['account_id'] = accountIds[_string(row, 'account_id')];
      final destination = _nullableString(row, 'destination_account_id');
      row['destination_account_id'] =
          destination == null ? null : accountIds[destination];
      final category = _nullableString(row, 'category_id');
      row['category_id'] = category == null ? null : categoryIds[category];
      final receipt = _nullableString(row, 'receipt_id');
      row['receipt_id'] = receipt == null ? null : receiptIds[receipt];
    }
    for (final row in _maps(data, 'plans')) {
      row['budget_id'] = newBudgetId;
      row['id'] = planIds[_string(row, 'id')];
      row['category_id'] = categoryIds[_string(row, 'category_id')];
    }

    if (sourceBudgetId == newBudgetId) {
      throw StateError('Generated restore budget id collides with source id.');
    }
    return _ClonedSnapshot(budgetId: newBudgetId, body: body);
  }

  Map<String, String> _idMap(List<Map<String, dynamic>> rows) {
    return {
      for (final row in rows) _string(row, 'id'): _idGenerator.nextId(),
    };
  }

  BudgetBackupPreview _previewFromBody({
    required int formatVersion,
    required DateTime createdAt,
    required Map<String, dynamic> body,
  }) {
    final data = _map(body, 'data');
    final budget = _map(data, 'budget');
    return BudgetBackupPreview(
      formatVersion: formatVersion,
      sourceBudgetId: _string(body, 'budget_id'),
      budgetName: _string(budget, 'name'),
      baseCurrency: _string(budget, 'base_currency'),
      createdAt: createdAt,
      memberCount: _maps(data, 'members').length,
      categoryCount: _maps(data, 'categories').length,
      accountCount: _maps(data, 'accounts').length,
      transactionCount: _maps(data, 'transactions').length,
      planCount: _maps(data, 'plans').length,
      receiptCount: _maps(data, 'receipts').length,
    );
  }
}

final class _ValidatedBackup {
  const _ValidatedBackup({required this.backup, required this.snapshot});

  final DecodedBudgetBackup backup;
  final DecodedBudgetSnapshot snapshot;
}

final class _ClonedSnapshot {
  const _ClonedSnapshot({required this.budgetId, required this.body});

  final String budgetId;
  final Map<String, dynamic> body;
}

Map<String, dynamic> _map(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! Map<String, dynamic>) {
    throw const BudgetBackupError(
      BudgetBackupErrorCode.invalidSnapshot,
      'Backup snapshot имеет неверную структуру.',
    );
  }
  return result;
}

List<Map<String, dynamic>> _maps(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! List) {
    throw const BudgetBackupError(
      BudgetBackupErrorCode.invalidSnapshot,
      'Backup snapshot имеет неверную структуру.',
    );
  }
  return result.cast<Map<String, dynamic>>();
}

String _string(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw const BudgetBackupError(
      BudgetBackupErrorCode.invalidSnapshot,
      'Backup snapshot содержит неверное строковое поле.',
    );
  }
  return value;
}

String? _nullableString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is! String) {
    throw const BudgetBackupError(
      BudgetBackupErrorCode.invalidSnapshot,
      'Backup snapshot содержит неверное optional поле.',
    );
  }
  return value;
}

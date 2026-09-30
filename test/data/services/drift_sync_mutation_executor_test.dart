import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/services/drift_sync_mutation_executor.dart';
import 'package:budget_accounting_system/src/domain/models/sync_mutation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SyncDao syncDao;
  late DriftSyncMutationExecutor executor;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    syncDao = SyncDao(database);
    executor = DriftSyncMutationExecutor(
      database: database,
      syncDao: syncDao,
      idGenerator: _Ids(['op-generated']),
      signatureService: const _Signer(),
    );

    await database.into(database.users).insert(
      UsersCompanion.insert(
        id: 'user-1',
        name: 'Alice',
        publicKey: 'ed25519:test',
      ),
    );
    await database.into(database.devices).insert(
      DevicesCompanion.insert(id: 'device-1', userId: 'user-1'),
    );
    await database.into(database.budgets).insert(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Household',
        baseCurrency: 'EUR',
        createdBy: 'user-1',
      ),
    );
  });

  tearDown(() => database.close());

  SyncMutationDraft draft({String? operationId}) {
    return SyncMutationDraft(
      spec: SyncMutationSpec(
        budgetId: 'budget-1',
        entityType: 'category',
        entityId: 'category-1',
        type: SyncMutationType.create,
        patch: const {'name': 'Food', 'kind': 'EXPENSE'},
        operationId: operationId,
      ),
      authorId: 'user-1',
      deviceId: 'device-1',
    );
  }

  Future<void> insertCategory() {
    return database.into(database.categories).insert(
      CategoriesCompanion.insert(
        id: 'category-1',
        budgetId: 'budget-1',
        name: 'Food',
        kind: 'EXPENSE',
      ),
    );
  }

  test('commits domain mutation and signed operation in one transaction', () async {
    await executor.execute<void>(
      draft: draft(operationId: 'op-1'),
      mutate: insertCategory,
    );

    final category = await (database.select(database.categories)
          ..where((row) => row.id.equals('category-1')))
        .getSingle();
    final operation = await syncDao.findById('op-1');

    expect(category.name, 'Food');
    expect(operation, isNotNull);
    expect(operation!.logicalClock, BigInt.one);
    expect(operation.deviceId, 'device-1');
    expect(operation.signature, utf8.encode('signature'));
  });

  test('Lamport clock grows monotonically for the device', () async {
    await executor.execute<void>(
      draft: draft(operationId: 'op-1'),
      mutate: insertCategory,
    );
    await executor.execute<void>(
      draft: SyncMutationDraft(
        spec: const SyncMutationSpec(
          budgetId: 'budget-1',
          entityType: 'category',
          entityId: 'category-1',
          type: SyncMutationType.patch,
          patch: {'name': 'Groceries'},
          operationId: 'op-2',
        ),
        authorId: 'user-1',
        deviceId: 'device-1',
      ),
      mutate: () => (database.update(database.categories)
            ..where((row) => row.id.equals('category-1')))
          .write(const CategoriesCompanion(name: Value('Groceries'))),
    );

    expect((await syncDao.findById('op-1'))!.logicalClock, BigInt.one);
    expect((await syncDao.findById('op-2'))!.logicalClock, BigInt.from(2));
  });

  test('duplicate operation id does not run domain mutation', () async {
    await executor.execute<void>(
      draft: draft(operationId: 'op-1'),
      mutate: insertCategory,
    );

    var called = false;
    await expectLater(
      executor.execute<void>(
        draft: draft(operationId: 'op-1'),
        mutate: () async {
          called = true;
        },
      ),
      throwsA(isA<Exception>()),
    );

    expect(called, isFalse);
    expect(await syncDao.getOperationsAfter(
      budgetId: 'budget-1',
      logicalClock: BigInt.zero,
    ), hasLength(1));
  });

  test('rolls back domain mutation when journal insert fails', () async {
    final invalidDraft = SyncMutationDraft(
      spec: const SyncMutationSpec(
        budgetId: 'budget-1',
        entityType: 'category',
        entityId: 'category-1',
        type: SyncMutationType.create,
        patch: {'name': 'Food', 'kind': 'EXPENSE'},
        operationId: 'op-invalid-author',
      ),
      authorId: 'missing-user',
      deviceId: 'device-1',
    );

    await expectLater(
      executor.execute<void>(
        draft: invalidDraft,
        mutate: insertCategory,
      ),
      throwsA(anything),
    );

    expect(
      await (database.select(database.categories)
            ..where((row) => row.id.equals('category-1')))
          .getSingleOrNull(),
      isNull,
    );
    expect(await syncDao.findById('op-invalid-author'), isNull);
  });

  test('does not append operation when mutation reports no change', () async {
    final result = await executor.execute<bool>(
      draft: draft(operationId: 'op-noop'),
      mutate: () async => false,
      shouldRecord: (changed) => changed,
    );

    expect(result, isFalse);
    expect(await syncDao.findById('op-noop'), isNull);
    expect(
      await syncDao.getMaxLogicalClockForDevice('device-1'),
      BigInt.zero,
    );
  });

  test('rolls back domain mutation when mutation callback fails', () async {
    await expectLater(
      executor.execute<void>(
        draft: draft(operationId: 'op-rollback'),
        mutate: () async {
          await insertCategory();
          throw StateError('boom');
        },
      ),
      throwsStateError,
    );

    expect(
      await (database.select(database.categories)
            ..where((row) => row.id.equals('category-1')))
          .getSingleOrNull(),
      isNull,
    );
    expect(await syncDao.findById('op-rollback'), isNull);
  });
}

final class _Ids implements IdGenerator {
  _Ids(this.values);

  final List<String> values;
  var index = 0;

  @override
  String nextId() => values[index++];
}

final class _Signer implements IdentitySignatureService {
  const _Signer();

  @override
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  }) async {
    return base64Url.encode(utf8.encode('signature'));
  }

  @override
  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  }) async {
    return true;
  }
}

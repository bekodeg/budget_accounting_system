import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/application/errors/budget_snapshot_error.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/application/services/sync_operation_codec.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_budget_snapshot_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_identity_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_sync_journal.dart';
import 'package:budget_accounting_system/src/data/services/drift_sync_materializer.dart';
import 'package:budget_accounting_system/src/domain/models/budget_snapshot.dart';
import 'package:budget_accounting_system/src/domain/models/sync_mutation.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Fixture source;
  late _Fixture target;

  setUp(() async {
    source = await _Fixture.create(seedBudget: true);
    target = await _Fixture.create(seedBudget: false);
  });

  tearDown(() async {
    await source.database.close();
    await target.database.close();
  });

  test('snapshot plus concurrent tail converges without replaying full history', () async {
    await source.seedCategoryCreate(
      operationId: 'op-1',
      clock: 1,
      name: 'Food',
    );

    final snapshot = await source.snapshots.create('budget-1');

    await source.renameCategory(
      operationId: 'op-2',
      clock: 2,
      name: 'Groceries',
    );

    await target.snapshots.apply(
      expectedBudgetId: 'budget-1',
      snapshot: snapshot,
    );

    final imported =
        await (target.database.select(target.database.categories)
              ..where((row) => row.id.equals('category-1')))
            .getSingle();
    expect(imported.name, 'Food');

    final targetVector = await target.journal.stateVector('budget-1');
    expect(targetVector.clockFor('device-a'), BigInt.one);

    final tail = await source.journal.missingOperations(
      budgetId: 'budget-1',
      remoteState: targetVector,
      limit: 100,
    );
    expect(
      tail.operations.map((wire) => wire.operation.operationId),
      ['op-2'],
    );

    await target.journal.ingest(
      budgetId: 'budget-1',
      operations: tail.operations,
    );

    final converged =
        await (target.database.select(target.database.categories)
              ..where((row) => row.id.equals('category-1')))
            .getSingle();
    expect(converged.name, 'Groceries');
    expect(
      await target.journal.stateVector('budget-1'),
      await source.journal.stateVector('budget-1'),
    );
  });

  test('corrupted snapshot does not replace local data', () async {
    await source.seedCategoryCreate(
      operationId: 'op-1',
      clock: 1,
      name: 'Food',
    );
    final snapshot = await source.snapshots.create('budget-1');
    final corrupted = BudgetSnapshotPackage(
      bodyJson: snapshot.bodyJson.replaceFirst('Food', 'Tampered'),
      digestBase64: snapshot.digestBase64,
    );

    await expectLater(
      target.snapshots.apply(
        expectedBudgetId: 'budget-1',
        snapshot: corrupted,
      ),
      throwsA(
        isA<BudgetSnapshotError>().having(
          (error) => error.code,
          'code',
          BudgetSnapshotErrorCode.digestMismatch,
        ),
      ),
    );

    expect(
      await (target.database.select(target.database.budgets)
            ..where((row) => row.id.equals('budget-1')))
          .getSingleOrNull(),
      isNull,
    );
    expect(
      await (target.database.select(target.database.categories)
            ..where((row) => row.id.equals('category-1')))
          .getSingleOrNull(),
      isNull,
    );
  });
}

final class _Fixture {
  _Fixture({
    required this.database,
    required this.syncDao,
    required this.snapshots,
    required this.journal,
    required this.signatures,
  });

  final AppDatabase database;
  final SyncDao syncDao;
  final DriftBudgetSnapshotRepository snapshots;
  final DriftSyncJournal journal;
  final _SignatureService signatures;

  static Future<_Fixture> create({required bool seedBudget}) async {
    final database = AppDatabase(NativeDatabase.memory());
    final userBudgetDao = UserBudgetDao(database);
    final syncDao = SyncDao(database);
    const signatures = _SignatureService();
    final identity = DriftIdentityRepository(userBudgetDao);
    final materializer = DriftSyncMaterializer(
      database: database,
      syncDao: syncDao,
    );
    final snapshots = DriftBudgetSnapshotRepository(
      database: database,
      syncDao: syncDao,
      signatureService: signatures,
    );
    final journal = DriftSyncJournal(
      database: database,
      syncDao: syncDao,
      identityRepository: identity,
      signatureService: signatures,
      materializer: materializer,
    );

    if (seedBudget) {
      await userBudgetDao.upsertUser(
        UsersCompanion.insert(
          id: 'user-a',
          name: 'Alice',
          publicKey: 'ed25519:user-a',
        ),
      );
      await database.into(database.devices).insert(
        DevicesCompanion.insert(id: 'device-a', userId: 'user-a'),
      );
      await userBudgetDao.upsertBudget(
        BudgetsCompanion.insert(
          id: 'budget-1',
          name: 'Shared',
          baseCurrency: 'EUR',
          createdBy: 'user-a',
        ),
      );
      await userBudgetDao.upsertMember(
        BudgetMembersCompanion.insert(
          budgetId: 'budget-1',
          userId: 'user-a',
          role: 'OWNER',
        ),
      );
    }

    return _Fixture(
      database: database,
      syncDao: syncDao,
      snapshots: snapshots,
      journal: journal,
      signatures: signatures,
    );
  }

  Future<void> seedCategoryCreate({
    required String operationId,
    required int clock,
    required String name,
  }) async {
    await database.into(database.categories).insert(
      CategoriesCompanion.insert(
        id: 'category-1',
        budgetId: 'budget-1',
        name: name,
        kind: 'EXPENSE',
      ),
    );
    await _append(
      SignedSyncOperation(
        operationId: operationId,
        budgetId: 'budget-1',
        entityType: 'category',
        entityId: 'category-1',
        type: SyncMutationType.create,
        patchJson:
            '{"is_archived":false,"kind":"EXPENSE","name":"$name"}',
        authorId: 'user-a',
        deviceId: 'device-a',
        logicalClock: BigInt.from(clock),
        createdAt: DateTime.utc(2026, 9, 30, 10, clock),
      ),
    );
  }

  Future<void> renameCategory({
    required String operationId,
    required int clock,
    required String name,
  }) async {
    await (database.update(database.categories)
          ..where((row) => row.id.equals('category-1')))
        .write(CategoriesCompanion(name: Value(name)));
    await _append(
      SignedSyncOperation(
        operationId: operationId,
        budgetId: 'budget-1',
        entityType: 'category',
        entityId: 'category-1',
        type: SyncMutationType.patch,
        patchJson: '{"name":"$name"}',
        authorId: 'user-a',
        deviceId: 'device-a',
        logicalClock: BigInt.from(clock),
        createdAt: DateTime.utc(2026, 9, 30, 10, clock),
      ),
    );
  }

  Future<void> _append(SignedSyncOperation operation) async {
    final signature = await signatures.sign(
      deviceId: operation.deviceId,
      message: const SyncOperationCodec().signingBytes(operation),
    );
    await syncDao.appendStrict(
      SyncOperationsCompanion.insert(
        opId: operation.operationId,
        budgetId: operation.budgetId,
        entityType: operation.entityType,
        entityId: operation.entityId,
        opType: switch (operation.type) {
          SyncMutationType.create => 'CREATE',
          SyncMutationType.patch => 'PATCH',
          SyncMutationType.delete => 'DELETE',
        },
        patch: operation.patchJson,
        authorId: operation.authorId,
        deviceId: operation.deviceId,
        logicalClock: operation.logicalClock,
        signature: base64Url.decode(signature),
        createdAt: Value(operation.createdAt),
      ),
    );
  }
}

final class _SignatureService implements IdentitySignatureService {
  const _SignatureService();

  @override
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  }) async {
    return base64Url.encode(message);
  }

  @override
  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  }) async {
    return signature == base64Url.encode(message);
  }
}

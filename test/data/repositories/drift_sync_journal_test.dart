import 'dart:convert';

import 'package:budget_accounting_system/src/application/errors/sync_protocol_error.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/application/services/sync_operation_codec.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_identity_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_sync_journal.dart';
import 'package:budget_accounting_system/src/data/services/drift_sync_materializer.dart';
import 'package:budget_accounting_system/src/domain/models/sync_mutation.dart';
import 'package:budget_accounting_system/src/domain/models/sync_protocol.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Fixture source;
  late _Fixture target;

  setUp(() async {
    source = await _Fixture.create();
    target = await _Fixture.create();
  });

  tearDown(() async {
    await source.database.close();
    await target.database.close();
  });

  test('state vector and missing page are tracked per device', () async {
    await source.add(_operation('a-1', device: 'device-a', clock: 1));
    await source.add(_operation('a-2', device: 'device-a', clock: 2));
    await source.add(_operation('b-1', device: 'device-b', clock: 1));

    final vector = await source.journal.stateVector('budget-1');
    expect(vector.clocks, {'device-a': BigInt.from(2), 'device-b': BigInt.one});

    final page = await source.journal.missingOperations(
      budgetId: 'budget-1',
      remoteState: SyncStateVector({
        'device-a': BigInt.one,
        'device-b': BigInt.one,
      }),
      limit: 10,
    );
    expect(page.operations.map((item) => item.operation.operationId), ['a-2']);
    expect(page.hasMore, isFalse);

    final limited = await source.journal.missingOperations(
      budgetId: 'budget-1',
      remoteState: const SyncStateVector.empty(),
      limit: 2,
    );
    expect(limited.operations, hasLength(2));
    expect(limited.hasMore, isTrue);
  });

  test('remote create is materialized into the domain table', () async {
    final operation = SignedSyncOperation(
      operationId: 'category-create',
      budgetId: 'budget-1',
      entityType: 'category',
      entityId: 'category-remote',
      type: SyncMutationType.create,
      patchJson: '{"is_archived":false,"kind":"EXPENSE","name":"Remote food"}',
      authorId: 'user-a',
      deviceId: 'device-a',
      logicalClock: BigInt.one,
      createdAt: DateTime.utc(2026, 9, 30, 10),
    );

    await target.journal.ingest(
      budgetId: 'budget-1',
      operations: [await source.wire(operation)],
    );

    final category = await (target.database.select(
      target.database.categories,
    )..where((row) => row.id.equals('category-remote'))).getSingleOrNull();

    expect(category, isNotNull);
    expect(category!.name, 'Remote food');
    expect(category.kind, 'EXPENSE');
  });

  test(
    'verified ingest is idempotent and rejects conflicting replay',
    () async {
      final operation = _operation('a-1', device: 'device-a', clock: 1);
      final wire = await source.wire(operation);

      final first = await target.journal.ingest(
        budgetId: 'budget-1',
        operations: [wire],
      );
      expect(first.inserted, 1);
      expect(first.duplicates, 0);

      final duplicate = await target.journal.ingest(
        budgetId: 'budget-1',
        operations: [wire],
      );
      expect(duplicate.inserted, 0);
      expect(duplicate.duplicates, 1);

      final conflicting = SyncWireOperation(
        operation: SignedSyncOperation(
          operationId: operation.operationId,
          budgetId: operation.budgetId,
          entityType: operation.entityType,
          entityId: operation.entityId,
          type: operation.type,
          patchJson: '{"name":"tampered"}',
          authorId: operation.authorId,
          deviceId: operation.deviceId,
          logicalClock: operation.logicalClock,
          createdAt: operation.createdAt,
        ),
        signature: wire.signature,
      );

      await expectLater(
        target.journal.ingest(budgetId: 'budget-1', operations: [conflicting]),
        throwsA(
          isA<SyncProtocolError>().having(
            (error) => error.code,
            'code',
            SyncProtocolErrorCode.operationCollision,
          ),
        ),
      );
    },
  );

  test('invalid remote signature rolls back batch', () async {
    final valid = await source.wire(
      _operation('a-1', device: 'device-a', clock: 1),
    );
    final invalidOperation = _operation('b-1', device: 'device-b', clock: 1);
    final invalid = SyncWireOperation(
      operation: invalidOperation,
      signature: base64Url.encode(utf8.encode('not-a-valid-signature')),
    );

    await expectLater(
      target.journal.ingest(budgetId: 'budget-1', operations: [valid, invalid]),
      throwsA(
        isA<SyncProtocolError>().having(
          (error) => error.code,
          'code',
          SyncProtocolErrorCode.invalidSignature,
        ),
      ),
    );

    expect(
      await target.journal.stateVector('budget-1'),
      const SyncStateVector.empty(),
    );
  });
}

SignedSyncOperation _operation(
  String id, {
  required String device,
  required int clock,
}) {
  final suffix = device == 'device-a' ? 'a' : 'b';
  return SignedSyncOperation(
    operationId: id,
    budgetId: 'budget-1',
    entityType: 'category',
    entityId: 'category-1',
    type: SyncMutationType.patch,
    patchJson: '{"name":"$id"}',
    authorId: 'user-$suffix',
    deviceId: device,
    logicalClock: BigInt.from(clock),
    createdAt: DateTime.utc(2026, 9, 30, 10, clock),
  );
}

final class _Fixture {
  _Fixture({
    required this.database,
    required this.syncDao,
    required this.journal,
    required this.signatures,
  });

  final AppDatabase database;
  final SyncDao syncDao;
  final DriftSyncJournal journal;
  final _SignatureService signatures;

  static Future<_Fixture> create() async {
    final database = AppDatabase(NativeDatabase.memory());
    final userBudgetDao = UserBudgetDao(database);
    final syncDao = SyncDao(database);
    const signatures = _SignatureService();

    for (final suffix in ['a', 'b']) {
      await userBudgetDao.upsertUser(
        UsersCompanion.insert(
          id: 'user-$suffix',
          name: 'User $suffix',
          publicKey: 'ed25519:user-$suffix',
        ),
      );
      await database
          .into(database.devices)
          .insert(
            DevicesCompanion.insert(
              id: 'device-$suffix',
              userId: 'user-$suffix',
            ),
          );
    }
    await userBudgetDao.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Shared budget',
        baseCurrency: 'EUR',
        createdBy: 'user-a',
      ),
    );

    return _Fixture(
      database: database,
      syncDao: syncDao,
      journal: DriftSyncJournal(
        database: database,
        syncDao: syncDao,
        identityRepository: DriftIdentityRepository(userBudgetDao),
        signatureService: signatures,
        materializer: DriftSyncMaterializer(
          database: database,
          syncDao: syncDao,
        ),
      ),
      signatures: signatures,
    );
  }

  Future<SyncWireOperation> wire(SignedSyncOperation operation) async {
    final signature = await signatures.sign(
      deviceId: operation.deviceId,
      message: const SyncOperationCodec().signingBytes(operation),
    );
    return SyncWireOperation(operation: operation, signature: signature);
  }

  Future<void> add(SignedSyncOperation operation) async {
    final item = await wire(operation);
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
        signature: base64Url.decode(item.signature),
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/application/ports/sync_mutation_context_provider.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_transaction_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/syncing_transaction_repository.dart';
import 'package:budget_accounting_system/src/data/services/drift_sync_mutation_executor.dart';
import 'package:budget_accounting_system/src/domain/models/budget_transaction_entry.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/public_identity.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/domain/value_objects/money.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SyncDao syncDao;
  late SyncingTransactionRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    syncDao = SyncDao(database);

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
    await database.into(database.accounts).insert(
      AccountsCompanion.insert(
        id: 'account-1',
        budgetId: 'budget-1',
        name: 'Card',
        currency: 'EUR',
      ),
    );
    await database.into(database.categories).insert(
      CategoriesCompanion.insert(
        id: 'category-1',
        budgetId: 'budget-1',
        name: 'Food',
        kind: 'EXPENSE',
      ),
    );

    final executor = DriftSyncMutationExecutor(
      database: database,
      syncDao: syncDao,
      idGenerator: _Ids(['op-1']),
      signatureService: const _Signer(),
    );
    repository = SyncingTransactionRepository(
      delegate: DriftTransactionRepository(TransactionDao(database)),
      executor: executor,
      contextProvider: const _Context(),
    );
  });

  tearDown(() => database.close());

  test('missing update returns false without sync operation', () async {
    final now = DateTime.utc(2026, 9, 30, 10);
    final missing = BudgetTransactionEntry(
      id: 'missing-tx',
      budgetId: 'budget-1',
      occurredAt: now,
      amount: Money.positive(
        minorUnits: BigInt.from(1250),
        currency: Currency('EUR'),
      ),
      type: TransactionType.expense,
      authorId: 'user-1',
      accountId: 'account-1',
      destinationAccountId: null,
      categoryId: 'category-1',
      description: null,
      createdAt: now,
      updatedAt: now,
    );

    final changed = await repository.updateTransaction(missing);

    expect(changed, isFalse);
    expect(
      await syncDao.getOperationsAfter(
        budgetId: 'budget-1',
        logicalClock: BigInt.zero,
      ),
      isEmpty,
    );
  });

  test('transaction create persists domain row and sync operation together', () async {
    final now = DateTime.utc(2026, 9, 30, 10);
    final transaction = BudgetTransactionEntry(
      id: 'tx-1',
      budgetId: 'budget-1',
      occurredAt: now,
      amount: Money.positive(
        minorUnits: BigInt.from(1250),
        currency: Currency('EUR'),
      ),
      type: TransactionType.expense,
      authorId: 'user-1',
      accountId: 'account-1',
      destinationAccountId: null,
      categoryId: 'category-1',
      description: 'Lunch',
      createdAt: now,
      updatedAt: now,
    );

    await repository.createTransaction(transaction);

    final stored = await (database.select(database.budgetTransactions)
          ..where((row) => row.id.equals('tx-1')))
        .getSingle();
    final operation = await syncDao.findById('op-1');

    expect(stored.amountMinor, BigInt.from(1250));
    expect(operation, isNotNull);
    expect(operation!.entityType, 'transaction');
    expect(operation.entityId, 'tx-1');
    expect(operation.opType, 'CREATE');
    expect(operation.authorId, 'user-1');
    expect(operation.deviceId, 'device-1');
    expect(operation.patch, contains('"amount_minor":"1250"'));
  });
}

final class _Context implements SyncMutationContextProvider {
  const _Context();

  @override
  Future<SyncMutationContext> current() async {
    return const SyncMutationContext(
      userId: 'user-1',
      identity: PublicIdentity(
        userId: 'user-1',
        deviceId: 'device-1',
        publicKey: 'ed25519:test',
      ),
    );
  }
}

final class _Ids implements IdGenerator {
  _Ids(this._values);

  final List<String> _values;
  var _index = 0;

  @override
  String nextId() => _values[_index++];
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

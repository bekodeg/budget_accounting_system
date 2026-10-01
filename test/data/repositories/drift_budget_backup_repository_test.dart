import 'dart:convert';

import 'package:budget_accounting_system/src/application/errors/budget_backup_error.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_budget_backup_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_budget_snapshot_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'encrypted backup restores complete budget into a new database',
    () async {
      final source = await _Fixture.create(seedBudget: true);
      final target = await _Fixture.create(seedBudget: false);
      addTearDown(source.database.close);
      addTearDown(target.database.close);

      final payload = await source.backups.createEncrypted(
        budgetId: 'budget-1',
        password: 'correct horse battery staple',
      );

      expect(payload, isNot(contains('Coffee')));
      expect(payload, isNot(contains('1250')));

      final preview = await target.backups.preview(
        payload: payload,
        password: 'correct horse battery staple',
      );
      expect(preview.budgetName, 'Shared');
      expect(preview.memberCount, 1);
      expect(preview.categoryCount, 1);
      expect(preview.accountCount, 1);
      expect(preview.transactionCount, 1);
      expect(preview.planCount, 1);
      expect(preview.receiptCount, 1);

      final restored = await target.backups.restore(
        payload: payload,
        password: 'correct horse battery staple',
      );
      expect(restored.budgetId, 'budget-1');
      expect(restored.restoredAsNewBudget, isFalse);

      final budget = await (target.database.select(
        target.database.budgets,
      )..where((row) => row.id.equals('budget-1'))).getSingle();
      expect(budget.name, 'Shared');

      expect(
        await (target.database.select(
          target.database.budgetMembers,
        )..where((row) => row.budgetId.equals('budget-1'))).get(),
        hasLength(1),
      );
      expect(
        await (target.database.select(
          target.database.categories,
        )..where((row) => row.budgetId.equals('budget-1'))).get(),
        hasLength(1),
      );
      expect(
        await (target.database.select(
          target.database.accounts,
        )..where((row) => row.budgetId.equals('budget-1'))).get(),
        hasLength(1),
      );

      final receipts = await (target.database.select(
        target.database.receipts,
      )..where((row) => row.budgetId.equals('budget-1'))).get();
      expect(receipts, hasLength(1));
      expect(receipts.single.rawQr, 't=20260930T1200&s=12.50');

      final transactions = await (target.database.select(
        target.database.budgetTransactions,
      )..where((row) => row.budgetId.equals('budget-1'))).get();
      expect(transactions, hasLength(1));
      expect(transactions.single.amountMinor, BigInt.from(1250));
      expect(transactions.single.receiptId, 'receipt-1');

      final plans = await (target.database.select(
        target.database.plans,
      )..where((row) => row.budgetId.equals('budget-1'))).get();
      expect(plans, hasLength(1));
      expect(plans.single.plannedAmountMinor, BigInt.from(50000));
    },
  );

  test('wrong password or corrupted backup does not mutate database', () async {
    final source = await _Fixture.create(seedBudget: true);
    final target = await _Fixture.create(seedBudget: false);
    addTearDown(source.database.close);
    addTearDown(target.database.close);

    final payload = await source.backups.createEncrypted(
      budgetId: 'budget-1',
      password: 'correct-password',
    );

    await expectLater(
      target.backups.restore(payload: payload, password: 'wrong-password'),
      throwsA(
        isA<BudgetBackupError>().having(
          (error) => error.code,
          'code',
          BudgetBackupErrorCode.wrongPasswordOrCorrupted,
        ),
      ),
    );

    expect(
      await target.database.select(target.database.budgets).get(),
      isEmpty,
    );
    expect(
      await target.database.select(target.database.budgetTransactions).get(),
      isEmpty,
    );

    final envelope = jsonDecode(payload) as Map<String, dynamic>;
    envelope['ciphertext'] = 'AAAA';
    await expectLater(
      target.backups.restore(
        payload: jsonEncode(envelope),
        password: 'correct-password',
      ),
      throwsA(isA<BudgetBackupError>()),
    );
    expect(
      await target.database.select(target.database.budgets).get(),
      isEmpty,
    );
  });

  test('budget id conflict restores as a separate remapped budget', () async {
    final source = await _Fixture.create(seedBudget: true);
    final target = await _Fixture.create(seedBudget: true, dataRows: false);
    addTearDown(source.database.close);
    addTearDown(target.database.close);

    final payload = await source.backups.createEncrypted(
      budgetId: 'budget-1',
      password: 'restore-password',
    );

    final restored = await target.backups.restore(
      payload: payload,
      password: 'restore-password',
    );

    expect(restored.restoredAsNewBudget, isTrue);
    expect(restored.budgetId, 'generated-1');
    expect(restored.budgetId, isNot('budget-1'));

    final budgets = await target.database.select(target.database.budgets).get();
    expect(budgets, hasLength(2));

    final cloned = await (target.database.select(
      target.database.budgets,
    )..where((row) => row.id.equals('generated-1'))).getSingle();
    expect(cloned.name, 'Shared (восстановлено)');

    final clonedTransactions = await (target.database.select(
      target.database.budgetTransactions,
    )..where((row) => row.budgetId.equals('generated-1'))).get();
    expect(clonedTransactions, hasLength(1));
    expect(clonedTransactions.single.id, isNot('transaction-1'));
    expect(clonedTransactions.single.accountId, isNot('account-1'));
    expect(clonedTransactions.single.categoryId, isNot('category-1'));
    expect(clonedTransactions.single.receiptId, isNot('receipt-1'));

    final checkpoint = await (target.database.select(
      target.database.syncOperations,
    )..where((row) => row.budgetId.equals('generated-1'))).get();
    expect(checkpoint, isEmpty);
  });
}

final class _Fixture {
  _Fixture({required this.database, required this.backups});

  final AppDatabase database;
  final DriftBudgetBackupRepository backups;

  static Future<_Fixture> create({
    required bool seedBudget,
    bool dataRows = true,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    final syncDao = SyncDao(database);
    const signatures = _SignatureService();
    final snapshots = DriftBudgetSnapshotRepository(
      database: database,
      syncDao: syncDao,
      signatureService: signatures,
    );
    final backups = DriftBudgetBackupRepository(
      database: database,
      snapshotRepository: snapshots,
      idGenerator: _IdGenerator(),
    );

    if (seedBudget) {
      await database
          .into(database.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Alice',
              publicKey: 'public-key-1',
            ),
          );
      await database
          .into(database.devices)
          .insert(DevicesCompanion.insert(id: 'device-1', userId: 'user-1'));
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'budget-1',
              name: 'Shared',
              baseCurrency: 'EUR',
              createdBy: 'user-1',
            ),
          );
      await database
          .into(database.budgetMembers)
          .insert(
            BudgetMembersCompanion.insert(
              budgetId: 'budget-1',
              userId: 'user-1',
              role: 'OWNER',
            ),
          );
    }

    if (seedBudget && dataRows) {
      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'category-1',
              budgetId: 'budget-1',
              name: 'Food',
              kind: 'EXPENSE',
            ),
          );
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account-1',
              budgetId: 'budget-1',
              name: 'Card',
              currency: 'EUR',
            ),
          );
      await database
          .into(database.receipts)
          .insert(
            ReceiptsCompanion.insert(
              id: 'receipt-1',
              budgetId: 'budget-1',
              rawQr: const Value('t=20260930T1200&s=12.50'),
              merchant: const Value('Coffee'),
              receiptTime: Value(DateTime.utc(2026, 9, 30, 12)),
              totalMinor: Value(BigInt.from(1250)),
              parsedPayload: const Value('{"source":"qr"}'),
              parseStatus: const Value('PARSED'),
            ),
          );
      await database
          .into(database.budgetTransactions)
          .insert(
            BudgetTransactionsCompanion.insert(
              id: 'transaction-1',
              budgetId: 'budget-1',
              occurredAt: DateTime.utc(2026, 9, 30, 12),
              amountMinor: BigInt.from(1250),
              currency: 'EUR',
              type: 'EXPENSE',
              authorId: 'user-1',
              accountId: 'account-1',
              categoryId: const Value('category-1'),
              receiptId: const Value('receipt-1'),
              description: const Value('Coffee'),
            ),
          );
      await database
          .into(database.plans)
          .insert(
            PlansCompanion.insert(
              id: 'plan-1',
              budgetId: 'budget-1',
              month: DateTime.utc(2026, 9),
              categoryId: 'category-1',
              plannedAmountMinor: BigInt.from(50000),
            ),
          );
    }

    return _Fixture(database: database, backups: backups);
  }
}

final class _IdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String nextId() => 'generated-${++_next}';
}

final class _SignatureService implements IdentitySignatureService {
  const _SignatureService();

  @override
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  }) async => base64Url.encode(message);

  @override
  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  }) async => signature == base64Url.encode(message);
}

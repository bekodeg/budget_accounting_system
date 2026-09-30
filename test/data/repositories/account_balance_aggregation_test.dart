import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_account_repository.dart';
import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CategoryAccountDao accountDao;
  late TransactionDao transactionDao;
  late DriftAccountRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final userBudgetDao = UserBudgetDao(database);
    accountDao = CategoryAccountDao(database);
    transactionDao = TransactionDao(database);
    repository = DriftAccountRepository(accountDao);

    await userBudgetDao.upsertUser(
      UsersCompanion.insert(
        id: 'user-1',
        name: 'Alice',
        publicKey: 'public-key',
      ),
    );
    await userBudgetDao.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Household',
        baseCurrency: 'EUR',
        createdBy: 'user-1',
      ),
    );
    await userBudgetDao.upsertMember(
      BudgetMembersCompanion.insert(
        budgetId: 'budget-1',
        userId: 'user-1',
        role: 'OWNER',
      ),
    );

    for (final entry in [('cash', 10000), ('bank', 2000)]) {
      await repository.createAccount(
        BudgetAccount(
          id: entry.$1,
          budgetId: 'budget-1',
          name: entry.$1,
          openingBalanceMinor: BigInt.from(entry.$2),
          currency: Currency('EUR'),
          isArchived: false,
        ),
      );
    }
  });

  tearDown(() => database.close());

  Future<void> tx({
    required String id,
    required DateTime at,
    required int amount,
    required String type,
    required String accountId,
    String? destinationAccountId,
    DateTime? deletedAt,
  }) {
    return transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: id,
        budgetId: 'budget-1',
        occurredAt: at,
        amountMinor: BigInt.from(amount),
        currency: 'EUR',
        type: type,
        authorId: 'user-1',
        accountId: accountId,
        destinationAccountId: Value(destinationAccountId),
        deletedAt: Value(deletedAt),
      ),
    );
  }

  test(
    'aggregates current and point-in-time balances from transaction history',
    () async {
      await tx(
        id: 'income',
        at: DateTime(2026, 9, 1, 10),
        amount: 5000,
        type: 'INCOME',
        accountId: 'cash',
      );
      await tx(
        id: 'expense',
        at: DateTime(2026, 9, 2, 10),
        amount: 2000,
        type: 'EXPENSE',
        accountId: 'cash',
      );
      await tx(
        id: 'transfer',
        at: DateTime(2026, 9, 3, 10),
        amount: 3000,
        type: 'TRANSFER',
        accountId: 'cash',
        destinationAccountId: 'bank',
      );
      await tx(
        id: 'deleted-expense',
        at: DateTime(2026, 9, 3, 11),
        amount: 999,
        type: 'EXPENSE',
        accountId: 'cash',
        deletedAt: DateTime(2026, 9, 4),
      );
      await tx(
        id: 'future-income',
        at: DateTime(2026, 9, 10, 10),
        amount: 7000,
        type: 'INCOME',
        accountId: 'cash',
      );

      final historical = await repository.getBalance(
        budgetId: 'budget-1',
        accountId: 'cash',
        atInclusive: DateTime(2026, 9, 3, 10),
      );
      expect(historical?.minorUnits, BigInt.from(10000));

      final current = await repository.getBalances(
        budgetId: 'budget-1',
        includeArchived: true,
      );
      expect(
        current
            .singleWhere((balance) => balance.accountId == 'cash')
            .minorUnits,
        BigInt.from(17000),
      );
      expect(
        current
            .singleWhere((balance) => balance.accountId == 'bank')
            .minorUnits,
        BigInt.from(5000),
      );
    },
  );

  test('archived account stays available for historical balance', () async {
    await tx(
      id: 'transfer',
      at: DateTime(2026, 9, 3, 10),
      amount: 3000,
      type: 'TRANSFER',
      accountId: 'cash',
      destinationAccountId: 'bank',
    );
    await accountDao.setAccountArchived(
      budgetId: 'budget-1',
      accountId: 'bank',
      isArchived: true,
    );

    final active = await repository.getBalances(
      budgetId: 'budget-1',
      includeArchived: false,
    );
    final all = await repository.getBalances(
      budgetId: 'budget-1',
      includeArchived: true,
    );

    expect(active.map((balance) => balance.accountId), isNot(contains('bank')));
    expect(
      all.singleWhere((balance) => balance.accountId == 'bank').minorUnits,
      BigInt.from(5000),
    );
  });
}

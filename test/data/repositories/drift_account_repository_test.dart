import 'package:budget_accounting_system/src/application/errors/account_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
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
  late UserBudgetDao userBudgetDao;
  late CategoryAccountDao accountDao;
  late TransactionDao transactionDao;
  late DriftAccountRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    userBudgetDao = UserBudgetDao(database);
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
    for (final budgetId in ['budget-1', 'budget-2']) {
      await userBudgetDao.upsertBudget(
        BudgetsCompanion.insert(
          id: budgetId,
          name: budgetId,
          baseCurrency: 'EUR',
          createdBy: 'user-1',
        ),
      );
      await userBudgetDao.upsertMember(
        BudgetMembersCompanion.insert(
          budgetId: budgetId,
          userId: 'user-1',
          role: 'OWNER',
        ),
      );
    }
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> createAccount({
    required String id,
    required String budgetId,
    required int openingBalanceMinor,
  }) {
    return repository.createAccount(
      BudgetAccount(
        id: id,
        budgetId: budgetId,
        name: id,
        openingBalanceMinor: BigInt.from(openingBalanceMinor),
        currency: Currency('EUR'),
        isArchived: false,
      ),
    );
  }

  test('lists only accounts from requested budget in stable order', () async {
    await createAccount(
      id: 'b',
      budgetId: 'budget-1',
      openingBalanceMinor: 0,
    );
    await createAccount(
      id: 'a',
      budgetId: 'budget-1',
      openingBalanceMinor: 0,
    );
    await createAccount(
      id: 'foreign',
      budgetId: 'budget-2',
      openingBalanceMinor: 0,
    );

    final accounts = await repository
        .watchAccounts('budget-1', includeArchived: false)
        .first;

    expect(accounts.map((account) => account.id).toList(), ['a', 'b']);
  });

  test('balance includes opening income expense and transfer directions', () async {
    await createAccount(
      id: 'source',
      budgetId: 'budget-1',
      openingBalanceMinor: 10000,
    );
    await createAccount(
      id: 'destination',
      budgetId: 'budget-1',
      openingBalanceMinor: 1000,
    );

    await transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'income',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 20),
        amountMinor: BigInt.from(5000),
        currency: 'EUR',
        type: 'INCOME',
        authorId: 'user-1',
        accountId: 'source',
      ),
    );
    await transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'expense',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 21),
        amountMinor: BigInt.from(2000),
        currency: 'EUR',
        type: 'EXPENSE',
        authorId: 'user-1',
        accountId: 'source',
      ),
    );
    await transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'transfer',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 22),
        amountMinor: BigInt.from(3000),
        currency: 'EUR',
        type: 'TRANSFER',
        authorId: 'user-1',
        accountId: 'source',
        destinationAccountId: const Value('destination'),
      ),
    );

    final source = await repository.getBalance(
      budgetId: 'budget-1',
      accountId: 'source',
    );
    final destination = await repository.getBalance(
      budgetId: 'budget-1',
      accountId: 'destination',
    );

    expect(source?.minorUnits, BigInt.from(10000));
    expect(destination?.minorUnits, BigInt.from(4000));
  });

  test('soft deleted transactions do not affect balance', () async {
    await createAccount(
      id: 'account-1',
      budgetId: 'budget-1',
      openingBalanceMinor: 10000,
    );
    await transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'income',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 20),
        amountMinor: BigInt.from(5000),
        currency: 'EUR',
        type: 'INCOME',
        authorId: 'user-1',
        accountId: 'account-1',
      ),
    );
    await transactionDao.softDelete(
      budgetId: 'budget-1',
      id: 'income',
      deletedAt: DateTime(2026, 9, 23),
    );

    final balance = await repository.getBalance(
      budgetId: 'budget-1',
      accountId: 'account-1',
    );

    expect(balance?.minorUnits, BigInt.from(10000));
    expect(
      await repository.hasTransactions(
        budgetId: 'budget-1',
        accountId: 'account-1',
      ),
      isTrue,
    );
  });

  test('transaction DAO rejects source account from another budget', () async {
    await createAccount(
      id: 'foreign',
      budgetId: 'budget-2',
      openingBalanceMinor: 0,
    );

    await expectLater(
      transactionDao.upsert(
        BudgetTransactionsCompanion.insert(
          id: 'invalid',
          budgetId: 'budget-1',
          occurredAt: DateTime(2026, 9, 23),
          amountMinor: BigInt.from(1000),
          currency: 'EUR',
          type: 'EXPENSE',
          authorId: 'user-1',
          accountId: 'foreign',
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await transactionDao.findById('invalid'), isNull);
  });

  test('archive hides account from active list but preserves transaction', () async {
    await createAccount(
      id: 'account-1',
      budgetId: 'budget-1',
      openingBalanceMinor: 0,
    );
    await transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'expense',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 21),
        amountMinor: BigInt.from(1000),
        currency: 'EUR',
        type: 'EXPENSE',
        authorId: 'user-1',
        accountId: 'account-1',
      ),
    );

    expect(
      await repository.setAccountArchived(
        budgetId: 'budget-1',
        accountId: 'account-1',
        isArchived: true,
      ),
      isTrue,
    );

    final active = await repository
        .watchAccounts('budget-1', includeArchived: false)
        .first;
    final all = await repository
        .watchAccounts('budget-1', includeArchived: true)
        .first;
    final transaction = await transactionDao.findById('expense');

    expect(active, isEmpty);
    expect(all.single.isArchived, isTrue);
    expect(transaction?.accountId, 'account-1');
  });

  test('budget guard rejects account belonging to another budget', () async {
    await createAccount(
      id: 'foreign',
      budgetId: 'budget-2',
      openingBalanceMinor: 0,
    );
    final guard = RequireAccountInBudget(repository);

    await expectLater(
      guard(budgetId: 'budget-1', accountId: 'foreign'),
      throwsA(
        isA<AccountError>().having(
          (error) => error.code,
          'code',
          AccountErrorCode.accountNotFound,
        ),
      ),
    );
  });
}

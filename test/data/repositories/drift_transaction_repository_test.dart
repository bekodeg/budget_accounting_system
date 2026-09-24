import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_transaction_repository.dart';
import 'package:budget_accounting_system/src/domain/models/budget_transaction_entry.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/transaction_filter.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/domain/value_objects/money.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao userBudgetDao;
  late CategoryAccountDao categoryAccountDao;
  late DriftTransactionRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    userBudgetDao = UserBudgetDao(database);
    categoryAccountDao = CategoryAccountDao(database);
    repository = DriftTransactionRepository(TransactionDao(database));

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
        name: 'Home',
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
    await categoryAccountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'account-1',
        budgetId: 'budget-1',
        name: 'Card',
        currency: 'EUR',
      ),
    );
    await categoryAccountDao.upsertCategory(
      CategoriesCompanion.insert(
        id: 'category-1',
        budgetId: 'budget-1',
        name: 'Food',
        kind: 'EXPENSE',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  BudgetTransactionEntry entry({
    required String id,
    required int amountMinor,
    DateTime? occurredAt,
  }) {
    final now = DateTime(2026, 9, 24, 10);
    return BudgetTransactionEntry(
      id: id,
      budgetId: 'budget-1',
      occurredAt: occurredAt ?? now,
      amount: Money.positive(
        minorUnits: BigInt.from(amountMinor),
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
  }

  test('create and watch returns newest operations first', () async {
    await repository.createTransaction(
      entry(id: 'old', amountMinor: 100, occurredAt: DateTime(2026, 9, 23)),
    );
    await repository.createTransaction(
      entry(id: 'new', amountMinor: 200, occurredAt: DateTime(2026, 9, 24)),
    );

    final items = await repository.watchActiveTransactions('budget-1').first;

    expect(items.map((item) => item.id).toList(), ['new', 'old']);
  });

  test('update only changes active transaction in requested budget', () async {
    final created = entry(id: 'transaction-1', amountMinor: 100);
    await repository.createTransaction(created);

    final updated = BudgetTransactionEntry(
      id: created.id,
      budgetId: created.budgetId,
      occurredAt: created.occurredAt,
      amount: Money.positive(
        minorUnits: BigInt.from(500),
        currency: Currency('EUR'),
      ),
      type: created.type,
      authorId: created.authorId,
      accountId: created.accountId,
      destinationAccountId: null,
      categoryId: created.categoryId,
      description: 'updated',
      createdAt: created.createdAt,
      updatedAt: created.updatedAt.add(const Duration(minutes: 1)),
    );

    expect(await repository.updateTransaction(updated), isTrue);
    final found = await repository.findActiveTransaction(
      budgetId: 'budget-1',
      transactionId: 'transaction-1',
    );
    expect(found?.amount.minorUnits, BigInt.from(500));
    expect(found?.description, 'updated');
  });

  test('combines period type category account and author filters', () async {
    await repository.createTransaction(
      entry(
        id: 'expense-in-range',
        amountMinor: 100,
        occurredAt: DateTime(2026, 9, 24, 10),
      ),
    );
    await repository.createTransaction(
      entry(
        id: 'expense-outside',
        amountMinor: 200,
        occurredAt: DateTime(2026, 8, 24, 10),
      ),
    );

    final items = await repository
        .watchFilteredTransactions(
          const TransactionFilter(
            budgetId: 'budget-1',
            fromInclusive: null,
            toExclusive: null,
            type: TransactionType.expense,
            categoryId: 'category-1',
            accountId: 'account-1',
            authorId: 'user-1',
          ),
        )
        .first;

    expect(
      items.map((item) => item.id),
      containsAll(['expense-in-range', 'expense-outside']),
    );

    final september = await repository
        .watchFilteredTransactions(
          TransactionFilter(
            budgetId: 'budget-1',
            fromInclusive: DateTime(2026, 9),
            toExclusive: DateTime(2026, 10),
            type: TransactionType.expense,
            categoryId: 'category-1',
            accountId: 'account-1',
            authorId: 'user-1',
          ),
        )
        .first;

    expect(september.map((item) => item.id).toList(), ['expense-in-range']);
  });

  test('soft delete removes row from filtered queries', () async {
    await repository.createTransaction(entry(id: 'deleted', amountMinor: 100));
    await repository.softDeleteTransaction(
      budgetId: 'budget-1',
      transactionId: 'deleted',
      deletedAt: DateTime(2026, 9, 24, 11),
    );

    final items = await repository
        .watchFilteredTransactions(
          const TransactionFilter(budgetId: 'budget-1'),
        )
        .first;

    expect(items, isEmpty);
  });

  test(
    'soft delete removes row from active queries but keeps database row',
    () async {
      await repository.createTransaction(
        entry(id: 'transaction-1', amountMinor: 100),
      );

      expect(
        await repository.softDeleteTransaction(
          budgetId: 'budget-1',
          transactionId: 'transaction-1',
          deletedAt: DateTime(2026, 9, 24, 11),
        ),
        isTrue,
      );

      expect(
        await repository.watchActiveTransactions('budget-1').first,
        isEmpty,
      );
      final raw = await (database.select(
        database.budgetTransactions,
      )..where((row) => row.id.equals('transaction-1'))).getSingle();
      expect(raw.deletedAt, isNotNull);
    },
  );
}

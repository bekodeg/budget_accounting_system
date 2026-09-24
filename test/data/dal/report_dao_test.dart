import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/report_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ReportDao reports;
  late TransactionDao transactions;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    reports = ReportDao(database);
    transactions = TransactionDao(database);
    final users = UserBudgetDao(database);
    final accounts = CategoryAccountDao(database);

    await users.upsertUser(
      UsersCompanion.insert(
        id: 'user-1',
        name: 'Alice',
        publicKey: 'key',
      ),
    );
    await users.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Home',
        baseCurrency: 'EUR',
        createdBy: 'user-1',
      ),
    );
    await users.upsertMember(
      BudgetMembersCompanion.insert(
        budgetId: 'budget-1',
        userId: 'user-1',
        role: 'OWNER',
      ),
    );
    for (final id in ['source', 'destination']) {
      await accounts.upsertAccount(
        AccountsCompanion.insert(
          id: id,
          budgetId: 'budget-1',
          name: id,
          currency: 'EUR',
        ),
      );
    }

    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'income',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 10),
        amountMinor: BigInt.from(10000),
        currency: 'EUR',
        type: 'INCOME',
        authorId: 'user-1',
        accountId: 'source',
      ),
    );
    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'expense',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 11),
        amountMinor: BigInt.from(3000),
        currency: 'EUR',
        type: 'EXPENSE',
        authorId: 'user-1',
        accountId: 'source',
      ),
    );
    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'transfer',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 12),
        amountMinor: BigInt.from(5000),
        currency: 'EUR',
        type: 'TRANSFER',
        authorId: 'user-1',
        accountId: 'source',
        destinationAccountId: const Value('destination'),
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('period summary ignores transfers', () async {
    final summary = await reports.getPeriodSummary(
      budgetId: 'budget-1',
      fromInclusive: DateTime(2026, 9),
      toExclusive: DateTime(2026, 10),
    );

    expect(summary.incomeMinor, BigInt.from(10000));
    expect(summary.expenseMinor, BigInt.from(3000));
    expect(summary.netMinor, BigInt.from(7000));
  });
}

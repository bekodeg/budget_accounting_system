import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/report_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_dashboard_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftDashboardRepository repository;
  late TransactionDao transactions;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftDashboardRepository(ReportDao(database));
    transactions = TransactionDao(database);
    final users = UserBudgetDao(database);
    final accounts = CategoryAccountDao(database);

    await users.upsertUser(
      UsersCompanion.insert(id: 'user-1', name: 'Alice', publicKey: 'key'),
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

    await accounts.upsertAccount(
      AccountsCompanion.insert(
        id: 'eur-source',
        budgetId: 'budget-1',
        name: 'EUR source',
        openingBalanceMinor: Value(BigInt.from(10000)),
        currency: 'EUR',
      ),
    );
    await accounts.upsertAccount(
      AccountsCompanion.insert(
        id: 'eur-destination',
        budgetId: 'budget-1',
        name: 'EUR destination',
        currency: 'EUR',
      ),
    );
    await accounts.upsertAccount(
      AccountsCompanion.insert(
        id: 'usd',
        budgetId: 'budget-1',
        name: 'USD',
        openingBalanceMinor: Value(BigInt.from(5000)),
        currency: 'USD',
      ),
    );

    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'income-eur',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 10),
        amountMinor: BigInt.from(2000),
        currency: 'EUR',
        type: 'INCOME',
        authorId: 'user-1',
        accountId: 'eur-source',
      ),
    );
    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'expense-eur',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 11),
        amountMinor: BigInt.from(500),
        currency: 'EUR',
        type: 'EXPENSE',
        authorId: 'user-1',
        accountId: 'eur-source',
      ),
    );
    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'transfer-eur',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 12),
        amountMinor: BigInt.from(1000),
        currency: 'EUR',
        type: 'TRANSFER',
        authorId: 'user-1',
        accountId: 'eur-source',
        destinationAccountId: const Value('eur-destination'),
      ),
    );
    await transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'income-usd',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 13),
        amountMinor: BigInt.from(300),
        currency: 'USD',
        type: 'INCOME',
        authorId: 'user-1',
        accountId: 'usd',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'dashboard keeps currencies separate and transfer cash-flow neutral',
    () async {
      final summary = await repository
          .watchSummary(budgetId: 'budget-1', monthStart: DateTime(2026, 9))
          .first;

      expect(summary.incomeMinorByCurrency['EUR'], BigInt.from(2000));
      expect(summary.incomeMinorByCurrency['USD'], BigInt.from(300));
      expect(summary.expenseMinorByCurrency['EUR'], BigInt.from(500));
      expect(summary.netMinorByCurrency['EUR'], BigInt.from(1500));
      expect(summary.netMinorByCurrency['USD'], BigInt.from(300));

      expect(summary.balanceMinorByCurrency['EUR'], BigInt.from(11500));
      expect(summary.balanceMinorByCurrency['USD'], BigInt.from(5300));
    },
  );
}

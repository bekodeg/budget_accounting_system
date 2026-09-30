import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/plan_receipt_dao.dart';
import 'package:budget_accounting_system/src/data/dal/report_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_monthly_report_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TransactionDao transactions;
  late PlanReceiptDao plans;
  late DriftMonthlyReportRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final users = UserBudgetDao(database);
    final catalog = CategoryAccountDao(database);
    transactions = TransactionDao(database);
    plans = PlanReceiptDao(database);
    repository = DriftMonthlyReportRepository(ReportDao(database));

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

    for (final category in [
      ('food', 'Еда'),
      ('transport', 'Транспорт'),
      ('leisure', 'Развлечения'),
    ]) {
      await catalog.createCategory(
        CategoriesCompanion.insert(
          id: category.$1,
          budgetId: 'budget-1',
          name: category.$2,
          kind: 'EXPENSE',
        ),
      );
    }

    await catalog.createAccount(
      AccountsCompanion.insert(
        id: 'cash',
        budgetId: 'budget-1',
        name: 'Наличные',
        openingBalanceMinor: Value(BigInt.from(10000)),
        currency: 'EUR',
      ),
    );
    await catalog.createAccount(
      AccountsCompanion.insert(
        id: 'bank',
        budgetId: 'budget-1',
        name: 'Банк',
        currency: 'EUR',
      ),
    );
    await catalog.createAccount(
      AccountsCompanion.insert(
        id: 'usd',
        budgetId: 'budget-1',
        name: 'USD',
        openingBalanceMinor: Value(BigInt.from(5000)),
        currency: 'USD',
      ),
    );

    await plans.setPlanAmount(
      id: 'plan-food',
      budgetId: 'budget-1',
      month: DateTime(2026, 9, 15),
      categoryId: 'food',
      plannedAmountMinor: BigInt.from(10000),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    await plans.setPlanAmount(
      id: 'plan-transport',
      budgetId: 'budget-1',
      month: DateTime(2026, 9),
      categoryId: 'transport',
      plannedAmountMinor: BigInt.from(5000),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
  });

  tearDown(() => database.close());

  Future<void> tx({
    required String id,
    required DateTime at,
    required int amount,
    required String currency,
    required String type,
    required String accountId,
    String? categoryId,
    String? destinationAccountId,
    DateTime? deletedAt,
  }) {
    return transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: id,
        budgetId: 'budget-1',
        occurredAt: at,
        amountMinor: BigInt.from(amount),
        currency: currency,
        type: type,
        authorId: 'user-1',
        accountId: accountId,
        categoryId: Value(categoryId),
        destinationAccountId: Value(destinationAccountId),
        deletedAt: Value(deletedAt),
      ),
    );
  }

  test('builds monthly plan fact report without mixing currencies', () async {
    await tx(
      id: 'income-eur',
      at: DateTime(2026, 9, 2),
      amount: 20000,
      currency: 'EUR',
      type: 'INCOME',
      accountId: 'cash',
    );
    await tx(
      id: 'food-eur',
      at: DateTime(2026, 9, 3),
      amount: 7000,
      currency: 'EUR',
      type: 'EXPENSE',
      accountId: 'cash',
      categoryId: 'food',
    );
    await tx(
      id: 'food-usd',
      at: DateTime(2026, 9, 4),
      amount: 1000,
      currency: 'USD',
      type: 'EXPENSE',
      accountId: 'usd',
      categoryId: 'food',
    );
    await tx(
      id: 'leisure-eur',
      at: DateTime(2026, 9, 5),
      amount: 3000,
      currency: 'EUR',
      type: 'EXPENSE',
      accountId: 'cash',
      categoryId: 'leisure',
    );
    await tx(
      id: 'transfer',
      at: DateTime(2026, 9, 6),
      amount: 2000,
      currency: 'EUR',
      type: 'TRANSFER',
      accountId: 'cash',
      destinationAccountId: 'bank',
    );
    await tx(
      id: 'deleted',
      at: DateTime(2026, 9, 7),
      amount: 999,
      currency: 'EUR',
      type: 'EXPENSE',
      accountId: 'cash',
      categoryId: 'food',
      deletedAt: DateTime(2026, 9, 8),
    );
    await tx(
      id: 'october',
      at: DateTime(2026, 10, 1),
      amount: 4000,
      currency: 'EUR',
      type: 'EXPENSE',
      accountId: 'cash',
      categoryId: 'food',
    );

    final report = await repository
        .watchMonthlyReport(
          budgetId: 'budget-1',
          monthStart: DateTime(2026, 9, 20),
        )
        .first;

    expect(report.monthStart, DateTime(2026, 9));
    expect(report.baseCurrency, 'EUR');
    expect(report.incomeMinorByCurrency['EUR'], BigInt.from(20000));
    expect(report.expenseMinorByCurrency['EUR'], BigInt.from(10000));
    expect(report.expenseMinorByCurrency['USD'], BigInt.from(1000));
    expect(report.netMinorByCurrency['EUR'], BigInt.from(10000));
    expect(report.netMinorByCurrency['USD'], BigInt.from(-1000));

    final food = report.categories.singleWhere(
      (item) => item.categoryId == 'food',
    );
    expect(food.plannedAmountMinor, BigInt.from(10000));
    expect(food.actualMinorByCurrency['EUR'], BigInt.from(7000));
    expect(food.actualMinorByCurrency['USD'], BigInt.from(1000));
    expect(food.remainingMinor, BigInt.from(3000));

    final transport = report.categories.singleWhere(
      (item) => item.categoryId == 'transport',
    );
    expect(transport.plannedAmountMinor, BigInt.from(5000));
    expect(transport.actualMinorByCurrency, isEmpty);
    expect(transport.remainingMinor, BigInt.from(5000));

    final leisure = report.categories.singleWhere(
      (item) => item.categoryId == 'leisure',
    );
    expect(leisure.plannedAmountMinor, BigInt.zero);
    expect(leisure.actualPlanCurrencyMinor, BigInt.from(3000));
    expect(leisure.remainingMinor, BigInt.from(-3000));

    expect(
      report.accountBalances
          .singleWhere((item) => item.accountId == 'cash')
          .balance
          .minorUnits,
      BigInt.from(18000),
    );
    expect(
      report.accountBalances
          .singleWhere((item) => item.accountId == 'bank')
          .balance
          .minorUnits,
      BigInt.from(2000),
    );
    expect(
      report.accountBalances
          .singleWhere((item) => item.accountId == 'usd')
          .balance
          .minorUnits,
      BigInt.from(4000),
    );
  });

  test('keeps different months isolated and supports zero period', () async {
    await tx(
      id: 'october',
      at: DateTime(2026, 10, 5),
      amount: 2500,
      currency: 'EUR',
      type: 'EXPENSE',
      accountId: 'cash',
      categoryId: 'food',
    );

    final september = await repository
        .watchMonthlyReport(budgetId: 'budget-1', monthStart: DateTime(2026, 9))
        .first;
    final october = await repository
        .watchMonthlyReport(
          budgetId: 'budget-1',
          monthStart: DateTime(2026, 10),
        )
        .first;

    expect(september.expenseMinorByCurrency, isEmpty);
    expect(
      september.categories
          .singleWhere((item) => item.categoryId == 'food')
          .plannedAmountMinor,
      BigInt.from(10000),
    );
    expect(october.expenseMinorByCurrency['EUR'], BigInt.from(2500));
    expect(
      october.categories
          .singleWhere((item) => item.categoryId == 'food')
          .plannedAmountMinor,
      BigInt.zero,
    );
  });
}

import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/plan_receipt_dao.dart';
import 'package:budget_accounting_system/src/data/dal/report_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_extended_report_repository.dart';
import 'package:budget_accounting_system/src/domain/models/report_filter.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TransactionDao transactions;
  late PlanReceiptDao plans;
  late DriftExtendedReportRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final users = UserBudgetDao(database);
    final catalog = CategoryAccountDao(database);
    transactions = TransactionDao(database);
    plans = PlanReceiptDao(database);
    repository = DriftExtendedReportRepository(ReportDao(database));

    for (final user in [('user-1', 'Alice'), ('user-2', 'Bob')]) {
      await users.upsertUser(
        UsersCompanion.insert(
          id: user.$1,
          name: user.$2,
          publicKey: 'key-${user.$1}',
        ),
      );
    }
    await users.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Home',
        baseCurrency: 'EUR',
        createdBy: 'user-1',
      ),
    );
    for (final userId in ['user-1', 'user-2']) {
      await users.upsertMember(
        BudgetMembersCompanion.insert(
          budgetId: 'budget-1',
          userId: userId,
          role: userId == 'user-1' ? 'OWNER' : 'EDITOR',
        ),
      );
    }

    for (final category in [
      ('food', 'Еда'),
      ('transport', 'Транспорт'),
      ('salary', 'Зарплата'),
    ]) {
      await catalog.createCategory(
        CategoriesCompanion.insert(
          id: category.$1,
          budgetId: 'budget-1',
          name: category.$2,
          kind: category.$1 == 'salary' ? 'INCOME' : 'EXPENSE',
        ),
      );
    }
    for (final account in [('cash', 'Наличные'), ('card', 'Карта')]) {
      await catalog.createAccount(
        AccountsCompanion.insert(
          id: account.$1,
          budgetId: 'budget-1',
          name: account.$2,
          currency: 'EUR',
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
    required String authorId,
    required String currency,
    String? categoryId,
  }) {
    return transactions.upsert(
      BudgetTransactionsCompanion.insert(
        id: id,
        budgetId: 'budget-1',
        occurredAt: at,
        amountMinor: BigInt.from(amount),
        currency: currency,
        type: type,
        authorId: authorId,
        accountId: accountId,
        categoryId: Value(categoryId),
      ),
    );
  }

  test('period uses [from, to) boundaries and combines filters', () async {
    final from = DateTime(2026, 3, 1);
    final to = DateTime(2026, 4, 1);

    await tx(
      id: 'included-boundary',
      at: from,
      amount: 1000,
      type: 'EXPENSE',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'food',
    );
    await tx(
      id: 'excluded-upper-boundary',
      at: to,
      amount: 9000,
      type: 'EXPENSE',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'food',
    );
    await tx(
      id: 'wrong-account',
      at: DateTime(2026, 3, 10),
      amount: 2000,
      type: 'EXPENSE',
      accountId: 'card',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'food',
    );
    await tx(
      id: 'wrong-author',
      at: DateTime(2026, 3, 11),
      amount: 3000,
      type: 'EXPENSE',
      accountId: 'cash',
      authorId: 'user-2',
      currency: 'EUR',
      categoryId: 'food',
    );
    await tx(
      id: 'wrong-category',
      at: DateTime(2026, 3, 12),
      amount: 4000,
      type: 'EXPENSE',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'transport',
    );

    final unfiltered = await repository
        .watchPeriodReport(
          ReportFilter(
            budgetId: 'budget-1',
            fromInclusive: from,
            toExclusive: to,
          ),
        )
        .first;
    expect(unfiltered.expenseMinorByCurrency['EUR'], BigInt.from(10000));

    final filtered = await repository
        .watchPeriodReport(
          ReportFilter(
            budgetId: 'budget-1',
            fromInclusive: from,
            toExclusive: to,
            categoryIds: {'food'},
            accountIds: {'cash'},
            authorIds: {'user-1'},
          ),
        )
        .first;

    expect(filtered.expenseMinorByCurrency['EUR'], BigInt.from(1000));
    expect(filtered.categories, hasLength(1));
    expect(filtered.categories.single.categoryId, 'food');
    expect(
      filtered.categories.single.actualMinorByCurrency['EUR'],
      BigInt.from(1000),
    );
  });

  test('year total equals sum of monthly aggregates', () async {
    await plans.setPlanAmount(
      id: 'plan-jan',
      budgetId: 'budget-1',
      month: DateTime(2026, 1),
      categoryId: 'food',
      plannedAmountMinor: BigInt.from(5000),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await plans.setPlanAmount(
      id: 'plan-feb',
      budgetId: 'budget-1',
      month: DateTime(2026, 2),
      categoryId: 'transport',
      plannedAmountMinor: BigInt.from(3000),
      updatedAt: DateTime.utc(2026, 2, 1),
    );

    await tx(
      id: 'jan-income',
      at: DateTime(2026, 1, 5),
      amount: 10000,
      type: 'INCOME',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'salary',
    );
    await tx(
      id: 'jan-food',
      at: DateTime(2026, 1, 6),
      amount: 2000,
      type: 'EXPENSE',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'food',
    );
    await tx(
      id: 'feb-income',
      at: DateTime(2026, 2, 5),
      amount: 20000,
      type: 'INCOME',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'salary',
    );
    await tx(
      id: 'feb-transport',
      at: DateTime(2026, 2, 6),
      amount: 1000,
      type: 'EXPENSE',
      accountId: 'cash',
      authorId: 'user-1',
      currency: 'EUR',
      categoryId: 'transport',
    );
    await tx(
      id: 'feb-food-usd',
      at: DateTime(2026, 2, 7),
      amount: 500,
      type: 'EXPENSE',
      accountId: 'card',
      authorId: 'user-1',
      currency: 'USD',
      categoryId: 'food',
    );

    final report = await repository
        .watchYearReport(budgetId: 'budget-1', year: 2026)
        .first;

    expect(report.months, hasLength(12));
    expect(report.baseCurrency, 'EUR');
    expect(report.incomeMinorByCurrency['EUR'], BigInt.from(30000));
    expect(report.expenseMinorByCurrency['EUR'], BigInt.from(3000));
    expect(report.expenseMinorByCurrency['USD'], BigInt.from(500));
    expect(report.plannedAmountMinor, BigInt.from(8000));
    expect(report.actualBaseCurrencyMinor, BigInt.from(3000));
    expect(report.varianceMinor, BigInt.from(5000));

    final monthlyIncome = report.months.fold<BigInt>(
      BigInt.zero,
      (sum, month) =>
          sum + (month.incomeMinorByCurrency['EUR'] ?? BigInt.zero),
    );
    final monthlyExpense = report.months.fold<BigInt>(
      BigInt.zero,
      (sum, month) =>
          sum + (month.expenseMinorByCurrency['EUR'] ?? BigInt.zero),
    );

    expect(monthlyIncome, report.incomeMinorByCurrency['EUR']);
    expect(monthlyExpense, report.expenseMinorByCurrency['EUR']);
    expect(report.months[0].plannedAmountMinor, BigInt.from(5000));
    expect(report.months[0].actualBaseCurrencyMinor, BigInt.from(2000));
    expect(report.months[1].plannedAmountMinor, BigInt.from(3000));
    expect(report.months[1].actualBaseCurrencyMinor, BigInt.from(1000));

    final food = report.categories.singleWhere(
      (category) => category.categoryId == 'food',
    );
    expect(food.plannedAmountMinor, BigInt.from(5000));
    expect(food.actualMinorByCurrency['EUR'], BigInt.from(2000));
    expect(food.actualMinorByCurrency['USD'], BigInt.from(500));
    expect(food.varianceMinor, BigInt.from(3000));
  });
}

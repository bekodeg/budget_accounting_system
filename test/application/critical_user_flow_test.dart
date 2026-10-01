import 'package:budget_accounting_system/src/application/use_cases/create_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_initial_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/delete_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_category_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/set_monthly_plan_amount.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_monthly_report.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/monthly_report.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  test(
    'critical flow: onboarding -> budget -> categories -> account -> transactions -> plan -> report',
    () async {
      final budgets = FakeBudgetRepository();
      final categories = FakeCategoryRepository();
      final accounts = FakeAccountRepository();
      final transactions = FakeTransactionRepository();
      final plans = FakePlanRepository();
      final sessionStore = FakeSessionStore();

      final session = await CreateInitialBudget(
        budgetRepository: budgets,
        categoryRepository: categories,
        sessionStore: sessionStore,
        idGenerator: FakeIdGenerator(['user-1', 'budget-1', 'device-1']),
        identityKeyStore: FakeIdentityKeyStore(),
        identityKeyPairGenerator: FakeIdentityKeyPairGenerator(),
      )(
        userName: 'Alice',
        budgetName: 'Family',
        baseCurrency: Currency('EUR'),
        applyDefaultCategories: false,
      );

      expect(session.userId, 'user-1');
      expect(session.budgetId, 'budget-1');
      expect(sessionStore.currentBudgetId, 'budget-1');

      final createCategory = CreateCategory(
        categoryRepository: categories,
        idGenerator: FakeIdGenerator(['expense-food', 'income-salary']),
        authorization: FakeBudgetAuthorizationGuard(userId: session.userId),
      );
      final expenseCategory = await createCategory(
        budgetId: session.budgetId,
        name: 'Food',
        kind: CategoryKind.expense,
      );
      final incomeCategory = await createCategory(
        budgetId: session.budgetId,
        name: 'Salary',
        kind: CategoryKind.income,
      );

      final account = await CreateAccount(
        accountRepository: accounts,
        idGenerator: FakeIdGenerator(['account-1']),
        authorization: FakeBudgetAuthorizationGuard(userId: session.userId),
      )(
        budgetId: session.budgetId,
        name: 'Main card',
        currency: Currency('EUR'),
        openingBalanceMinor: BigInt.zero,
      );

      final createTransaction = CreateTransaction(
        transactionRepository: transactions,
        requireAccountInBudget: RequireAccountInBudget(accounts),
        requireCategoryInBudget: RequireCategoryInBudget(categories),
        idGenerator: FakeIdGenerator(['income-1', 'expense-1']),
        authorization: FakeBudgetAuthorizationGuard(userId: session.userId),
      );

      final income = await createTransaction(
        budgetId: session.budgetId,
        authorId: session.userId,
        occurredAt: DateTime(2026, 9, 5),
        amountMinor: BigInt.from(250000),
        type: TransactionType.income,
        accountId: account.id,
        categoryId: incomeCategory.id,
        description: 'Salary',
      );
      final expense = await createTransaction(
        budgetId: session.budgetId,
        authorId: session.userId,
        occurredAt: DateTime(2026, 9, 10),
        amountMinor: BigInt.from(50000),
        type: TransactionType.expense,
        accountId: account.id,
        categoryId: expenseCategory.id,
        description: 'Groceries',
      );

      expect(transactions.snapshot(session.budgetId), hasLength(2));

      await SetMonthlyPlanAmount(
        planRepository: plans,
        categoryRepository: categories,
        idGenerator: FakeIdGenerator(['plan-1']),
        authorization: FakeBudgetAuthorizationGuard(userId: session.userId),
      )(
        budgetId: session.budgetId,
        categoryId: expenseCategory.id,
        month: DateTime(2026, 9, 20),
        plannedAmountMinor: BigInt.from(70000),
      );

      expect(
        plans.snapshot(session.budgetId, DateTime(2026, 9)).single.plannedAmountMinor,
        BigInt.from(70000),
      );

      final report = MonthlyReport(
        monthStart: DateTime(2026, 9),
        baseCurrency: 'EUR',
        incomeMinorByCurrency: {'EUR': income.amount.minorUnits},
        expenseMinorByCurrency: {'EUR': expense.amount.minorUnits},
        categories: const [],
        accountBalances: const [],
      );
      final watched = await WatchMonthlyReport(
        FakeMonthlyReportRepository(report: report),
      )(budgetId: session.budgetId, month: DateTime(2026, 9, 30)).first;

      expect(watched.monthStart, DateTime(2026, 9));
      expect(watched.incomeMinorByCurrency['EUR'], BigInt.from(250000));
      expect(watched.expenseMinorByCurrency['EUR'], BigInt.from(50000));

      await DeleteTransaction(
        repository: transactions,
        authorization: FakeBudgetAuthorizationGuard(userId: session.userId),
      )(budgetId: session.budgetId, transactionId: expense.id);

      expect(transactions.snapshot(session.budgetId), [income]);
    },
  );
}

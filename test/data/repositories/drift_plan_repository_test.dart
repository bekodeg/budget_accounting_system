import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/plan_receipt_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_plan_repository.dart';
import 'package:budget_accounting_system/src/domain/models/monthly_plan.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao userBudgetDao;
  late CategoryAccountDao categoryDao;
  late DriftPlanRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    userBudgetDao = UserBudgetDao(database);
    categoryDao = CategoryAccountDao(database);
    repository = DriftPlanRepository(PlanReceiptDao(database));

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
    await categoryDao.createCategory(
      CategoriesCompanion.insert(
        id: 'category-1',
        budgetId: 'budget-1',
        name: 'Еда',
        kind: 'EXPENSE',
      ),
    );
  });

  tearDown(() => database.close());

  test('upserts one row per budget month and category', () async {
    await repository.upsert(
      MonthlyPlan(
        id: 'plan-1',
        budgetId: 'budget-1',
        month: DateTime(2026, 9, 29),
        categoryId: 'category-1',
        plannedAmountMinor: BigInt.from(10000),
        updatedAt: DateTime.utc(2026, 9, 29, 10),
      ),
    );
    await repository.upsert(
      MonthlyPlan(
        id: 'plan-2',
        budgetId: 'budget-1',
        month: DateTime(2026, 9, 30),
        categoryId: 'category-1',
        plannedAmountMinor: BigInt.from(25000),
        updatedAt: DateTime.utc(2026, 9, 29, 11),
      ),
    );

    final plans = await repository
        .watchMonth(budgetId: 'budget-1', month: DateTime(2026, 9, 15))
        .first;

    expect(plans, hasLength(1));
    expect(plans.single.id, 'plan-1');
    expect(plans.single.month, DateTime(2026, 9));
    expect(plans.single.plannedAmountMinor, BigInt.from(25000));
  });

  test('clear removes only selected month and category plan', () async {
    for (final month in [DateTime(2026, 9), DateTime(2026, 10)]) {
      await repository.upsert(
        MonthlyPlan(
          id: 'plan-${month.month}',
          budgetId: 'budget-1',
          month: month,
          categoryId: 'category-1',
          plannedAmountMinor: BigInt.from(10000),
          updatedAt: DateTime.utc(2026, month.month),
        ),
      );
    }

    await repository.clear(
      budgetId: 'budget-1',
      month: DateTime(2026, 9, 20),
      categoryId: 'category-1',
    );

    expect(
      await repository
          .watchMonth(budgetId: 'budget-1', month: DateTime(2026, 9))
          .first,
      isEmpty,
    );
    expect(
      await repository
          .watchMonth(budgetId: 'budget-1', month: DateTime(2026, 10))
          .first,
      hasLength(1),
    );
  });
}

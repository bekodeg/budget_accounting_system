import 'package:budget_accounting_system/src/application/errors/plan_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/set_monthly_plan_amount.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  FakeCategoryRepository categories() => FakeCategoryRepository(
    categoriesByBudget: {
      'budget-1': const [
        BudgetCategory(
          id: 'expense',
          budgetId: 'budget-1',
          name: 'Еда',
          kind: CategoryKind.expense,
          isArchived: false,
        ),
        BudgetCategory(
          id: 'both',
          budgetId: 'budget-1',
          name: 'Универсальная',
          kind: CategoryKind.both,
          isArchived: false,
        ),
        BudgetCategory(
          id: 'income',
          budgetId: 'budget-1',
          name: 'Зарплата',
          kind: CategoryKind.income,
          isArchived: false,
        ),
        BudgetCategory(
          id: 'archived',
          budgetId: 'budget-1',
          name: 'Старая',
          kind: CategoryKind.expense,
          isArchived: true,
        ),
      ],
    },
  );

  test('normalizes month and clears plan when amount becomes zero', () async {
    final plans = FakePlanRepository();
    final useCase = SetMonthlyPlanAmount(
      planRepository: plans,
      categoryRepository: categories(),
      idGenerator: FakeIdGenerator(['plan-1', 'plan-2']),
      authorization: FakeBudgetAuthorizationGuard(),
    );

    await useCase(
      budgetId: 'budget-1',
      categoryId: 'expense',
      month: DateTime(2026, 9, 29, 18, 45),
      plannedAmountMinor: BigInt.from(12500),
    );

    final created = plans.snapshot('budget-1', DateTime(2026, 9)).single;
    expect(created.month, DateTime(2026, 9));
    expect(created.plannedAmountMinor, BigInt.from(12500));

    await useCase(
      budgetId: 'budget-1',
      categoryId: 'expense',
      month: DateTime(2026, 9, 15),
      plannedAmountMinor: BigInt.zero,
    );

    expect(plans.snapshot('budget-1', DateTime(2026, 9)), isEmpty);
  });

  test('rejects negative, income and archived category plans', () async {
    final useCase = SetMonthlyPlanAmount(
      planRepository: FakePlanRepository(),
      categoryRepository: categories(),
      idGenerator: FakeIdGenerator(['plan-1', 'plan-2', 'plan-3']),
      authorization: FakeBudgetAuthorizationGuard(),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        categoryId: 'expense',
        month: DateTime(2026, 9),
        plannedAmountMinor: BigInt.from(-1),
      ),
      throwsA(
        isA<PlanError>().having(
          (error) => error.code,
          'code',
          PlanErrorCode.negativeAmount,
        ),
      ),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        categoryId: 'income',
        month: DateTime(2026, 9),
        plannedAmountMinor: BigInt.one,
      ),
      throwsA(
        isA<PlanError>().having(
          (error) => error.code,
          'code',
          PlanErrorCode.incomeCategory,
        ),
      ),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        categoryId: 'archived',
        month: DateTime(2026, 9),
        plannedAmountMinor: BigInt.one,
      ),
      throwsA(
        isA<PlanError>().having(
          (error) => error.code,
          'code',
          PlanErrorCode.categoryArchived,
        ),
      ),
    );
  });
}

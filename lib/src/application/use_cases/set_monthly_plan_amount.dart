import '../../domain/models/domain_types.dart';
import '../../domain/models/monthly_plan.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/plan_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/plan_error.dart';
import '../ports/id_generator.dart';

final class SetMonthlyPlanAmount {
  const SetMonthlyPlanAmount({
    required PlanRepository planRepository,
    required CategoryRepository categoryRepository,
    required IdGenerator idGenerator,
    required BudgetAuthorizationGuard authorization,
  }) : _planRepository = planRepository,
       _categoryRepository = categoryRepository,
       _idGenerator = idGenerator,
       _authorization = authorization;

  final PlanRepository _planRepository;
  final CategoryRepository _categoryRepository;
  final IdGenerator _idGenerator;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String categoryId,
    required DateTime month,
    required BigInt plannedAmountMinor,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    if (plannedAmountMinor.isNegative) {
      throw const PlanError(
        PlanErrorCode.negativeAmount,
        'Плановая сумма не может быть отрицательной.',
      );
    }

    final category = await _categoryRepository.findCategory(
      budgetId: budgetId,
      categoryId: categoryId,
    );
    if (category == null) {
      throw const PlanError(
        PlanErrorCode.categoryNotFound,
        'Категория не найдена в активном бюджете.',
      );
    }
    if (category.isArchived) {
      throw const PlanError(
        PlanErrorCode.categoryArchived,
        'Архивную категорию нельзя использовать для нового плана.',
      );
    }
    if (category.kind == CategoryKind.income) {
      throw const PlanError(
        PlanErrorCode.incomeCategory,
        'План расходов можно задавать только расходным категориям.',
      );
    }

    final normalizedMonth = normalizePlanMonth(month);
    if (plannedAmountMinor == BigInt.zero) {
      await _planRepository.clear(
        budgetId: budgetId,
        month: normalizedMonth,
        categoryId: categoryId,
      );
      return;
    }

    await _planRepository.upsert(
      MonthlyPlan(
        id: _idGenerator.nextId(),
        budgetId: budgetId,
        month: normalizedMonth,
        categoryId: categoryId,
        plannedAmountMinor: plannedAmountMinor,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

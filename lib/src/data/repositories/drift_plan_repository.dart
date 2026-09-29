import '../../domain/models/monthly_plan.dart';
import '../../domain/repositories/plan_repository.dart';
import '../dal/plan_receipt_dao.dart';

final class DriftPlanRepository implements PlanRepository {
  const DriftPlanRepository(this._dao);

  final PlanReceiptDao _dao;

  @override
  Stream<List<MonthlyPlan>> watchMonth({
    required String budgetId,
    required DateTime month,
  }) {
    return _dao
        .watchPlansForMonth(budgetId: budgetId, month: month)
        .map(
          (plans) => plans
              .map(
                (plan) => MonthlyPlan(
                  id: plan.id,
                  budgetId: plan.budgetId,
                  month: plan.month,
                  categoryId: plan.categoryId,
                  plannedAmountMinor: plan.plannedAmountMinor,
                  updatedAt: plan.updatedAt,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> upsert(MonthlyPlan plan) {
    return _dao.setPlanAmount(
      id: plan.id,
      budgetId: plan.budgetId,
      month: plan.month,
      categoryId: plan.categoryId,
      plannedAmountMinor: plan.plannedAmountMinor,
      updatedAt: plan.updatedAt,
    );
  }

  @override
  Future<void> clear({
    required String budgetId,
    required DateTime month,
    required String categoryId,
  }) {
    return _dao.clearPlan(
      budgetId: budgetId,
      month: month,
      categoryId: categoryId,
    );
  }
}

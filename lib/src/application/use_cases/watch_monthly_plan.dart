import '../../domain/models/monthly_plan.dart';
import '../../domain/repositories/plan_repository.dart';

final class WatchMonthlyPlan {
  const WatchMonthlyPlan(this._repository);

  final PlanRepository _repository;

  Stream<List<MonthlyPlan>> call({
    required String budgetId,
    required DateTime month,
  }) {
    return _repository.watchMonth(
      budgetId: budgetId,
      month: normalizePlanMonth(month),
    );
  }
}

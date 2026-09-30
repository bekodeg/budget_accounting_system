import '../models/monthly_plan.dart';

abstract interface class PlanRepository {
  Stream<List<MonthlyPlan>> watchMonth({
    required String budgetId,
    required DateTime month,
  });

  Future<void> upsert(MonthlyPlan plan);

  Future<void> clear({
    required String budgetId,
    required DateTime month,
    required String categoryId,
  });
}

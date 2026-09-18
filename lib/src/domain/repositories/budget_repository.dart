import '../models/budget_summary.dart';

abstract interface class BudgetRepository {
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId);
}

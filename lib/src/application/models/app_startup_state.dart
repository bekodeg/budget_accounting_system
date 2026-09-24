import '../../domain/models/budget_summary.dart';

final class AppStartupState {
  const AppStartupState({
    required this.userId,
    required this.budgets,
    required this.selectedBudgetId,
  });

  const AppStartupState.onboarding()
    : userId = null,
      budgets = const [],
      selectedBudgetId = null;

  final String? userId;
  final List<BudgetSummary> budgets;
  final String? selectedBudgetId;

  bool get needsOnboarding => userId == null || budgets.isEmpty;

  bool get needsBudgetSelection =>
      !needsOnboarding && selectedBudgetId == null && budgets.length > 1;
}

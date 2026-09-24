import '../../domain/models/budget_summary.dart';
import '../../domain/repositories/budget_repository.dart';
import '../models/app_startup_state.dart';
import '../ports/session_store.dart';

final class ResolveAppStartup {
  const ResolveAppStartup({
    required BudgetRepository budgetRepository,
    required SessionStore sessionStore,
  })  : _budgetRepository = budgetRepository,
        _sessionStore = sessionStore;

  final BudgetRepository _budgetRepository;
  final SessionStore _sessionStore;

  Future<AppStartupState> call() async {
    final storedUserId = await _sessionStore.loadCurrentUserId();
    if (storedUserId != null) {
      final storedUserBudgets = await _budgetRepository.getBudgetsForUser(
        storedUserId,
      );
      if (storedUserBudgets.isNotEmpty) {
        return _resolveBudgetSelection(storedUserId, storedUserBudgets);
      }
    }

    final fallbackUserId = await _budgetRepository.findFirstUserIdWithBudget();
    if (fallbackUserId == null) {
      return const AppStartupState.onboarding();
    }

    final fallbackBudgets = await _budgetRepository.getBudgetsForUser(
      fallbackUserId,
    );
    if (fallbackBudgets.isEmpty) {
      return const AppStartupState.onboarding();
    }

    return _resolveBudgetSelection(fallbackUserId, fallbackBudgets);
  }

  Future<AppStartupState> _resolveBudgetSelection(
    String userId,
    List<BudgetSummary> budgets,
  ) async {
    final storedBudgetId = await _sessionStore.loadCurrentBudgetId();
    final storedBudgetExists = budgets.any(
      (budget) => budget.id == storedBudgetId,
    );

    String? selectedBudgetId;
    if (storedBudgetExists) {
      selectedBudgetId = storedBudgetId;
    } else if (budgets.length == 1) {
      selectedBudgetId = budgets.single.id;
    }

    await _sessionStore.saveCurrentUserId(userId);
    if (selectedBudgetId != null) {
      await _sessionStore.saveCurrentBudgetId(selectedBudgetId);
    }

    return AppStartupState(
      userId: userId,
      budgets: budgets,
      selectedBudgetId: selectedBudgetId,
    );
  }
}

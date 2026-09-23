import '../../domain/models/app_session.dart';
import '../../domain/repositories/budget_repository.dart';
import '../errors/onboarding_error.dart';
import '../ports/session_store.dart';

final class SelectBudget {
  const SelectBudget({
    required BudgetRepository budgetRepository,
    required SessionStore sessionStore,
  })  : _budgetRepository = budgetRepository,
        _sessionStore = sessionStore;

  final BudgetRepository _budgetRepository;
  final SessionStore _sessionStore;

  Future<AppSession> call({
    required String userId,
    required String budgetId,
  }) async {
    final budgets = await _budgetRepository.getBudgetsForUser(userId);
    final hasAccess = budgets.any((budget) => budget.id == budgetId);

    if (!hasAccess) {
      throw const OnboardingError(
        code: OnboardingErrorCode.inaccessibleBudget,
        message: 'Бюджет недоступен текущему пользователю.',
      );
    }

    await _sessionStore.saveSession(
      userId: userId,
      budgetId: budgetId,
    );

    return AppSession(userId: userId, budgetId: budgetId);
  }
}

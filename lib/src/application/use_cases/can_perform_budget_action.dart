import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/authorization_error.dart';

final class CanPerformBudgetAction {
  const CanPerformBudgetAction(this._authorization);

  final BudgetAuthorizationGuard _authorization;

  Future<bool> call({
    required String budgetId,
    required BudgetAction action,
  }) async {
    try {
      await _authorization.require(budgetId: budgetId, action: action);
      return true;
    } on AuthorizationError {
      return false;
    }
  }
}

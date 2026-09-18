import '../../domain/models/budget_summary.dart';
import '../../domain/repositories/budget_repository.dart';

final class WatchUserBudgets {
  const WatchUserBudgets(this._repository);

  final BudgetRepository _repository;

  Stream<List<BudgetSummary>> call(String userId) {
    return _repository.watchBudgetsForUser(userId);
  }
}

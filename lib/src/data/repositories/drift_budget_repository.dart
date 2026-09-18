import '../../domain/models/budget_summary.dart';
import '../../domain/repositories/budget_repository.dart';
import '../dal/user_budget_dao.dart';

final class DriftBudgetRepository implements BudgetRepository {
  const DriftBudgetRepository(this._dao);

  final UserBudgetDao _dao;

  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    return _dao.watchBudgetsForUser(userId).map(
          (budgets) => budgets
              .map(
                (budget) => BudgetSummary(
                  id: budget.id,
                  name: budget.name,
                  baseCurrency: budget.baseCurrency,
                ),
              )
              .toList(growable: false),
        );
  }
}

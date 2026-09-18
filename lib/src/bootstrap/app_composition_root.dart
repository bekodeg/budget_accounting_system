import '../application/app_services.dart';
import '../application/use_cases/watch_user_budgets.dart';
import '../data/dal/dal.dart';
import '../data/repositories/drift_budget_repository.dart';

final class AppCompositionRoot {
  AppCompositionRoot._({
    required BudgetDal dal,
    required this.services,
  }) : _dal = dal;

  factory AppCompositionRoot.defaults() {
    final dal = BudgetDal.defaults();
    final budgetRepository = DriftBudgetRepository(dal.usersAndBudgets);

    return AppCompositionRoot._(
      dal: dal,
      services: AppServices(
        watchUserBudgets: WatchUserBudgets(budgetRepository),
      ),
    );
  }

  final BudgetDal _dal;
  final AppServices services;

  Future<void> close() => _dal.close();
}

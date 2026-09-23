import '../application/app_services.dart';
import '../application/use_cases/create_initial_budget.dart';
import '../application/use_cases/resolve_app_startup.dart';
import '../application/use_cases/select_budget.dart';
import '../application/use_cases/watch_user_budgets.dart';
import '../data/dal/dal.dart';
import '../data/preferences/shared_preferences_session_store.dart';
import '../data/repositories/drift_budget_repository.dart';
import '../data/services/secure_id_generator.dart';

final class AppCompositionRoot {
  AppCompositionRoot._({
    required BudgetDal dal,
    required this.services,
  }) : _dal = dal;

  factory AppCompositionRoot.defaults() {
    final dal = BudgetDal.defaults();
    final budgetRepository = DriftBudgetRepository(dal.usersAndBudgets);
    final sessionStore = SharedPreferencesSessionStore();
    final idGenerator = SecureIdGenerator();

    return AppCompositionRoot._(
      dal: dal,
      services: AppServices(
        createInitialBudget: CreateInitialBudget(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
          idGenerator: idGenerator,
        ),
        resolveAppStartup: ResolveAppStartup(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        selectBudget: SelectBudget(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        watchUserBudgets: WatchUserBudgets(budgetRepository),
      ),
    );
  }

  final BudgetDal _dal;
  final AppServices services;

  Future<void> close() => _dal.close();
}

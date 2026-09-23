import '../application/app_services.dart';
import '../application/use_cases/apply_category_templates.dart';
import '../application/use_cases/archive_category.dart';
import '../application/use_cases/create_category.dart';
import '../application/use_cases/create_initial_budget.dart';
import '../application/use_cases/rename_category.dart';
import '../application/use_cases/resolve_app_startup.dart';
import '../application/use_cases/select_budget.dart';
import '../application/use_cases/watch_budget_categories.dart';
import '../application/use_cases/watch_user_budgets.dart';
import '../data/dal/dal.dart';
import '../data/preferences/shared_preferences_session_store.dart';
import '../data/repositories/drift_budget_repository.dart';
import '../data/repositories/drift_category_repository.dart';
import '../data/services/secure_id_generator.dart';

final class AppCompositionRoot {
  AppCompositionRoot._({
    required BudgetDal dal,
    required this.services,
  }) : _dal = dal;

  factory AppCompositionRoot.defaults() {
    final dal = BudgetDal.defaults();
    final budgetRepository = DriftBudgetRepository(dal.usersAndBudgets);
    final categoryRepository = DriftCategoryRepository(
      dal.categoriesAndAccounts,
    );
    final sessionStore = SharedPreferencesSessionStore();
    final idGenerator = SecureIdGenerator();

    return AppCompositionRoot._(
      dal: dal,
      services: AppServices(
        applyCategoryTemplates: ApplyCategoryTemplates(categoryRepository),
        archiveCategory: ArchiveCategory(categoryRepository),
        createCategory: CreateCategory(
          categoryRepository: categoryRepository,
          idGenerator: idGenerator,
        ),
        createInitialBudget: CreateInitialBudget(
          budgetRepository: budgetRepository,
          categoryRepository: categoryRepository,
          sessionStore: sessionStore,
          idGenerator: idGenerator,
        ),
        renameCategory: RenameCategory(categoryRepository),
        resolveAppStartup: ResolveAppStartup(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        selectBudget: SelectBudget(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        watchBudgetCategories: WatchBudgetCategories(categoryRepository),
        watchUserBudgets: WatchUserBudgets(budgetRepository),
      ),
    );
  }

  final BudgetDal _dal;
  final AppServices services;

  Future<void> close() => _dal.close();
}

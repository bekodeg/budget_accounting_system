import 'use_cases/apply_category_templates.dart';
import 'use_cases/archive_category.dart';
import 'use_cases/create_category.dart';
import 'use_cases/create_initial_budget.dart';
import 'use_cases/rename_category.dart';
import 'use_cases/resolve_app_startup.dart';
import 'use_cases/select_budget.dart';
import 'use_cases/watch_budget_categories.dart';
import 'use_cases/watch_user_budgets.dart';

final class AppServices {
  const AppServices({
    required this.applyCategoryTemplates,
    required this.archiveCategory,
    required this.createCategory,
    required this.createInitialBudget,
    required this.renameCategory,
    required this.resolveAppStartup,
    required this.selectBudget,
    required this.watchBudgetCategories,
    required this.watchUserBudgets,
  });

  final ApplyCategoryTemplates applyCategoryTemplates;
  final ArchiveCategory archiveCategory;
  final CreateCategory createCategory;
  final CreateInitialBudget createInitialBudget;
  final RenameCategory renameCategory;
  final ResolveAppStartup resolveAppStartup;
  final SelectBudget selectBudget;
  final WatchBudgetCategories watchBudgetCategories;
  final WatchUserBudgets watchUserBudgets;
}

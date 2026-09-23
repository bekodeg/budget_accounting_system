import 'use_cases/create_initial_budget.dart';
import 'use_cases/resolve_app_startup.dart';
import 'use_cases/select_budget.dart';
import 'use_cases/watch_user_budgets.dart';

final class AppServices {
  const AppServices({
    required this.createInitialBudget,
    required this.resolveAppStartup,
    required this.selectBudget,
    required this.watchUserBudgets,
  });

  final CreateInitialBudget createInitialBudget;
  final ResolveAppStartup resolveAppStartup;
  final SelectBudget selectBudget;
  final WatchUserBudgets watchUserBudgets;
}

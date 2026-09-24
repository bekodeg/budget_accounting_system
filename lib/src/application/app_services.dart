import 'use_cases/apply_category_templates.dart';
import 'use_cases/archive_account.dart';
import 'use_cases/archive_category.dart';
import 'use_cases/create_account.dart';
import 'use_cases/create_category.dart';
import 'use_cases/create_initial_budget.dart';
import 'use_cases/create_transaction.dart';
import 'use_cases/delete_transaction.dart';
import 'use_cases/get_account_balance.dart';
import 'use_cases/rename_category.dart';
import 'use_cases/require_account_in_budget.dart';
import 'use_cases/require_category_in_budget.dart';
import 'use_cases/resolve_app_startup.dart';
import 'use_cases/select_budget.dart';
import 'use_cases/update_account.dart';
import 'use_cases/update_transaction.dart';
import 'use_cases/watch_budget_accounts.dart';
import 'use_cases/watch_budget_categories.dart';
import 'use_cases/watch_transactions.dart';
import 'use_cases/watch_user_budgets.dart';

final class AppServices {
  const AppServices({
    required this.applyCategoryTemplates,
    required this.archiveAccount,
    required this.archiveCategory,
    required this.createAccount,
    required this.createCategory,
    required this.createInitialBudget,
    required this.createTransaction,
    required this.deleteTransaction,
    required this.getAccountBalance,
    required this.renameCategory,
    required this.requireAccountInBudget,
    required this.requireCategoryInBudget,
    required this.resolveAppStartup,
    required this.selectBudget,
    required this.updateAccount,
    required this.updateTransaction,
    required this.watchBudgetAccounts,
    required this.watchBudgetCategories,
    required this.watchTransactions,
    required this.watchUserBudgets,
  });

  final ApplyCategoryTemplates applyCategoryTemplates;
  final ArchiveAccount archiveAccount;
  final ArchiveCategory archiveCategory;
  final CreateAccount createAccount;
  final CreateCategory createCategory;
  final CreateInitialBudget createInitialBudget;
  final CreateTransaction createTransaction;
  final DeleteTransaction deleteTransaction;
  final GetAccountBalance getAccountBalance;
  final RenameCategory renameCategory;
  final RequireAccountInBudget requireAccountInBudget;
  final RequireCategoryInBudget requireCategoryInBudget;
  final ResolveAppStartup resolveAppStartup;
  final SelectBudget selectBudget;
  final UpdateAccount updateAccount;
  final UpdateTransaction updateTransaction;
  final WatchBudgetAccounts watchBudgetAccounts;
  final WatchBudgetCategories watchBudgetCategories;
  final WatchTransactions watchTransactions;
  final WatchUserBudgets watchUserBudgets;
}

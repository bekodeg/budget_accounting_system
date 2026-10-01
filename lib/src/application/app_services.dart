import 'services/budget_snapshot_session_service.dart';
import 'services/lan_peer_session_manager.dart';
import 'services/sync_coordinator_service.dart';
import 'services/sync_session_service.dart';
import 'use_cases/accept_budget_invite.dart';
import 'use_cases/apply_budget_snapshot.dart';
import 'use_cases/apply_category_templates.dart';
import 'use_cases/archive_account.dart';
import 'use_cases/archive_category.dart';
import 'use_cases/can_perform_budget_action.dart';
import 'use_cases/create_account.dart';
import 'use_cases/create_budget_invite.dart';
import 'use_cases/create_budget_snapshot.dart';
import 'use_cases/create_category.dart';
import 'use_cases/create_initial_budget.dart';
import 'use_cases/create_transaction.dart';
import 'use_cases/create_transfer.dart';
import 'use_cases/delete_transaction.dart';
import 'use_cases/export_report.dart';
import 'use_cases/get_account_balance.dart';
import 'use_cases/get_budget_account_balances.dart';
import 'use_cases/get_public_identity.dart';
import 'use_cases/inspect_budget_invite.dart';
import 'use_cases/pick_budget_invite_file.dart';
import 'use_cases/rename_category.dart';
import 'use_cases/require_account_in_budget.dart';
import 'use_cases/require_category_in_budget.dart';
import 'use_cases/resolve_app_startup.dart';
import 'use_cases/select_budget.dart';
import 'use_cases/share_budget_invite_file.dart';
import 'use_cases/set_monthly_plan_amount.dart';
import 'use_cases/update_account.dart';
import 'use_cases/update_member_role.dart';
import 'use_cases/update_transaction.dart';
import 'use_cases/update_transfer.dart';
import 'use_cases/watch_budget_accounts.dart';
import 'use_cases/watch_budget_categories.dart';
import 'use_cases/watch_dashboard_summary.dart';
import 'use_cases/watch_filtered_transactions.dart';
import 'use_cases/watch_monthly_plan.dart';
import 'use_cases/watch_monthly_report.dart';
import 'use_cases/watch_budget_members.dart';
import 'use_cases/watch_period_report.dart';
import 'use_cases/watch_year_report.dart';
import 'use_cases/watch_transactions.dart';
import 'use_cases/watch_user_budgets.dart';

final class AppServices {
  const AppServices({
    required this.acceptBudgetInvite,
    this.applyBudgetSnapshot,
    required this.applyCategoryTemplates,
    required this.archiveAccount,
    required this.archiveCategory,
    required this.canPerformBudgetAction,
    required this.createAccount,
    required this.createBudgetInvite,
    this.createBudgetSnapshot,
    required this.createCategory,
    required this.createInitialBudget,
    required this.createTransaction,
    required this.createTransfer,
    required this.deleteTransaction,
    required this.exportReport,
    required this.getAccountBalance,
    required this.getBudgetAccountBalances,
    required this.getPublicIdentity,
    required this.inspectBudgetInvite,
    this.budgetSnapshotSessions,
    this.lanPeerSessions,
    this.syncCoordinator,
    this.syncSessions,
    required this.pickBudgetInviteFile,
    required this.renameCategory,
    required this.requireAccountInBudget,
    required this.requireCategoryInBudget,
    required this.resolveAppStartup,
    required this.selectBudget,
    required this.shareBudgetInviteFile,
    required this.setMonthlyPlanAmount,
    required this.updateAccount,
    required this.updateMemberRole,
    required this.updateTransaction,
    required this.updateTransfer,
    required this.watchBudgetAccounts,
    required this.watchBudgetCategories,
    required this.watchDashboardSummary,
    required this.watchFilteredTransactions,
    required this.watchMonthlyPlan,
    required this.watchMonthlyReport,
    required this.watchBudgetMembers,
    required this.watchPeriodReport,
    required this.watchYearReport,
    required this.watchTransactions,
    required this.watchUserBudgets,
  });

  final AcceptBudgetInvite acceptBudgetInvite;
  final ApplyBudgetSnapshot? applyBudgetSnapshot;
  final ApplyCategoryTemplates applyCategoryTemplates;
  final ArchiveAccount archiveAccount;
  final ArchiveCategory archiveCategory;
  final CanPerformBudgetAction canPerformBudgetAction;
  final CreateAccount createAccount;
  final CreateBudgetInvite createBudgetInvite;
  final CreateBudgetSnapshot? createBudgetSnapshot;
  final CreateCategory createCategory;
  final CreateInitialBudget createInitialBudget;
  final CreateTransaction createTransaction;
  final CreateTransfer createTransfer;
  final DeleteTransaction deleteTransaction;
  final ExportReport exportReport;
  final GetAccountBalance getAccountBalance;
  final GetBudgetAccountBalances getBudgetAccountBalances;
  final GetPublicIdentity getPublicIdentity;
  final InspectBudgetInvite inspectBudgetInvite;
  final BudgetSnapshotSessionService? budgetSnapshotSessions;
  final LanPeerSessionManager? lanPeerSessions;
  final SyncCoordinatorService? syncCoordinator;
  final SyncSessionService? syncSessions;
  final PickBudgetInviteFile pickBudgetInviteFile;
  final RenameCategory renameCategory;
  final RequireAccountInBudget requireAccountInBudget;
  final RequireCategoryInBudget requireCategoryInBudget;
  final ResolveAppStartup resolveAppStartup;
  final SelectBudget selectBudget;
  final ShareBudgetInviteFile shareBudgetInviteFile;
  final SetMonthlyPlanAmount setMonthlyPlanAmount;
  final UpdateAccount updateAccount;
  final UpdateMemberRole updateMemberRole;
  final UpdateTransaction updateTransaction;
  final UpdateTransfer updateTransfer;
  final WatchBudgetAccounts watchBudgetAccounts;
  final WatchBudgetCategories watchBudgetCategories;
  final WatchDashboardSummary watchDashboardSummary;
  final WatchFilteredTransactions watchFilteredTransactions;
  final WatchMonthlyPlan watchMonthlyPlan;
  final WatchMonthlyReport watchMonthlyReport;
  final WatchBudgetMembers watchBudgetMembers;
  final WatchPeriodReport watchPeriodReport;
  final WatchYearReport watchYearReport;
  final WatchTransactions watchTransactions;
  final WatchUserBudgets watchUserBudgets;
}

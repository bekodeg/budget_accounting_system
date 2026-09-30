import '../application/app_services.dart';
import '../application/use_cases/apply_category_templates.dart';
import '../application/use_cases/archive_account.dart';
import '../application/use_cases/archive_category.dart';
import '../application/use_cases/create_account.dart';
import '../application/use_cases/create_category.dart';
import '../application/use_cases/create_initial_budget.dart';
import '../application/use_cases/create_transaction.dart';
import '../application/use_cases/create_transfer.dart';
import '../application/use_cases/delete_transaction.dart';
import '../application/use_cases/export_report.dart';
import '../application/use_cases/export_report.dart';
import '../application/use_cases/get_account_balance.dart';
import '../application/use_cases/get_budget_account_balances.dart';
import '../application/use_cases/rename_category.dart';
import '../application/use_cases/require_account_in_budget.dart';
import '../application/use_cases/require_category_in_budget.dart';
import '../application/use_cases/resolve_app_startup.dart';
import '../application/use_cases/select_budget.dart';
import '../application/use_cases/set_monthly_plan_amount.dart';
import '../application/use_cases/update_account.dart';
import '../application/use_cases/update_transaction.dart';
import '../application/use_cases/update_transfer.dart';
import '../application/use_cases/watch_budget_accounts.dart';
import '../application/use_cases/watch_budget_categories.dart';
import '../application/use_cases/watch_dashboard_summary.dart';
import '../application/use_cases/watch_filtered_transactions.dart';
import '../application/use_cases/watch_monthly_plan.dart';
import '../application/use_cases/watch_monthly_report.dart';
import '../application/use_cases/watch_period_report.dart';
import '../application/use_cases/watch_year_report.dart';
import '../application/use_cases/watch_transactions.dart';
import '../application/use_cases/watch_user_budgets.dart';
import '../data/dal/dal.dart';
import '../data/preferences/shared_preferences_session_store.dart';
import '../data/repositories/drift_account_repository.dart';
import '../data/repositories/drift_budget_repository.dart';
import '../data/repositories/drift_category_repository.dart';
import '../data/repositories/drift_dashboard_repository.dart';
import '../data/repositories/drift_extended_report_repository.dart';
import '../data/repositories/drift_report_export_repository.dart';
import '../data/repositories/drift_plan_repository.dart';
import '../data/repositories/drift_report_export_repository.dart';
import '../data/repositories/drift_monthly_report_repository.dart';
import '../data/repositories/drift_transaction_repository.dart';
import '../data/services/excel_report_document_encoder.dart';
import '../data/services/platform_report_share_gateway.dart';
import '../data/services/local_report_document_encoder.dart';
import '../data/services/local_report_share_gateway.dart';
import '../data/services/secure_id_generator.dart';

final class AppCompositionRoot {
  AppCompositionRoot._({required BudgetDal dal, required this.services})
    : _dal = dal;

  factory AppCompositionRoot.defaults() {
    final dal = BudgetDal.defaults();
    final budgetRepository = DriftBudgetRepository(dal.usersAndBudgets);
    final categoryRepository = DriftCategoryRepository(
      dal.categoriesAndAccounts,
    );
    final accountRepository = DriftAccountRepository(dal.categoriesAndAccounts);
    final transactionRepository = DriftTransactionRepository(dal.transactions);
    final dashboardRepository = DriftDashboardRepository(dal.reports);
    final planRepository = DriftPlanRepository(dal.plansAndReceipts);
    final monthlyReportRepository = DriftMonthlyReportRepository(dal.reports);
    final extendedReportRepository = DriftExtendedReportRepository(dal.reports);
    final reportExportRepository = DriftReportExportRepository(dal.transactions);
    const reportDocumentEncoder = LocalReportDocumentEncoder();
    final reportShareGateway = LocalReportShareGateway();
    final reportExportRepository = DriftReportExportRepository(dal.transactions);
    final sessionStore = SharedPreferencesSessionStore();
    final idGenerator = SecureIdGenerator();
    final requireAccountInBudget = RequireAccountInBudget(accountRepository);
    final requireCategoryInBudget = RequireCategoryInBudget(categoryRepository);

    return AppCompositionRoot._(
      dal: dal,
      services: AppServices(
        applyCategoryTemplates: ApplyCategoryTemplates(categoryRepository),
        archiveAccount: ArchiveAccount(accountRepository),
        archiveCategory: ArchiveCategory(categoryRepository),
        createAccount: CreateAccount(
          accountRepository: accountRepository,
          idGenerator: idGenerator,
        ),
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
        createTransaction: CreateTransaction(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          requireCategoryInBudget: requireCategoryInBudget,
          idGenerator: idGenerator,
        ),
        createTransfer: CreateTransfer(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          idGenerator: idGenerator,
        ),
        deleteTransaction: DeleteTransaction(transactionRepository),
        exportReport: ExportReport(
          reportRepository: extendedReportRepository,
          exportRepository: reportExportRepository,
          encoder: reportDocumentEncoder,
          shareGateway: reportShareGateway,
        ),
        exportReport: ExportReport(
          reportRepository: extendedReportRepository,
          exportRepository: reportExportRepository,
          encoder: const ExcelReportDocumentEncoder(),
          shareGateway: const PlatformReportShareGateway(),
        ),
        getAccountBalance: GetAccountBalance(accountRepository),
        getBudgetAccountBalances: GetBudgetAccountBalances(accountRepository),
        renameCategory: RenameCategory(categoryRepository),
        requireAccountInBudget: requireAccountInBudget,
        requireCategoryInBudget: requireCategoryInBudget,
        resolveAppStartup: ResolveAppStartup(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        selectBudget: SelectBudget(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        setMonthlyPlanAmount: SetMonthlyPlanAmount(
          planRepository: planRepository,
          categoryRepository: categoryRepository,
          idGenerator: idGenerator,
        ),
        updateAccount: UpdateAccount(accountRepository),
        updateTransaction: UpdateTransaction(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          requireCategoryInBudget: requireCategoryInBudget,
        ),
        updateTransfer: UpdateTransfer(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
        ),
        watchBudgetAccounts: WatchBudgetAccounts(accountRepository),
        watchBudgetCategories: WatchBudgetCategories(categoryRepository),
        watchDashboardSummary: WatchDashboardSummary(dashboardRepository),
        watchFilteredTransactions: WatchFilteredTransactions(
          transactionRepository,
        ),
        watchMonthlyPlan: WatchMonthlyPlan(planRepository),
        watchMonthlyReport: WatchMonthlyReport(monthlyReportRepository),
        watchPeriodReport: WatchPeriodReport(extendedReportRepository),
        watchYearReport: WatchYearReport(extendedReportRepository),
        watchTransactions: WatchTransactions(transactionRepository),
        watchUserBudgets: WatchUserBudgets(budgetRepository),
      ),
    );
  }

  final BudgetDal _dal;
  final AppServices services;

  Future<void> close() => _dal.close();
}

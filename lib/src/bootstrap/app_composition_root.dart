import '../application/app_services.dart';
import '../application/services/budget_transport_secret_manager.dart';
import '../application/services/lan_discovery_token_service.dart';
import '../application/services/lan_handshake_service.dart';
import '../application/services/lan_peer_session_manager.dart';
import '../application/services/lan_secure_session_service.dart';
import '../application/services/lan_session_crypto.dart';
import '../application/services/sync_session_service.dart';
import '../application/services/session_sync_mutation_context_provider.dart';
import '../application/use_cases/accept_budget_invite.dart';
import '../application/use_cases/apply_category_templates.dart';
import '../application/use_cases/archive_account.dart';
import '../application/use_cases/archive_category.dart';
import '../application/use_cases/authorize_budget_action.dart';
import '../application/use_cases/can_perform_budget_action.dart';
import '../application/use_cases/create_account.dart';
import '../application/use_cases/create_budget_invite.dart';
import '../application/use_cases/create_category.dart';
import '../application/use_cases/create_initial_budget.dart';
import '../application/use_cases/create_transaction.dart';
import '../application/use_cases/create_transfer.dart';
import '../application/use_cases/delete_transaction.dart';
import '../application/use_cases/export_report.dart';
import '../application/use_cases/get_account_balance.dart';
import '../application/use_cases/get_budget_account_balances.dart';
import '../application/use_cases/get_public_identity.dart';
import '../application/use_cases/inspect_budget_invite.dart';
import '../application/use_cases/pick_budget_invite_file.dart';
import '../application/use_cases/ensure_local_identity.dart';
import '../application/use_cases/rename_category.dart';
import '../application/use_cases/require_account_in_budget.dart';
import '../application/use_cases/require_category_in_budget.dart';
import '../application/use_cases/resolve_app_startup.dart';
import '../application/use_cases/select_budget.dart';
import '../application/use_cases/share_budget_invite_file.dart';
import '../application/use_cases/set_monthly_plan_amount.dart';
import '../application/use_cases/update_account.dart';
import '../application/use_cases/update_member_role.dart';
import '../application/use_cases/update_transaction.dart';
import '../application/use_cases/update_transfer.dart';
import '../application/use_cases/watch_budget_accounts.dart';
import '../application/use_cases/watch_budget_categories.dart';
import '../application/use_cases/watch_dashboard_summary.dart';
import '../application/use_cases/watch_filtered_transactions.dart';
import '../application/use_cases/watch_monthly_plan.dart';
import '../application/use_cases/watch_monthly_report.dart';
import '../application/use_cases/watch_budget_members.dart';
import '../application/use_cases/watch_period_report.dart';
import '../application/use_cases/watch_year_report.dart';
import '../application/use_cases/watch_transactions.dart';
import '../application/use_cases/watch_user_budgets.dart';
import '../data/dal/dal.dart';
import '../data/network/io_lan_local_address_resolver.dart';
import '../data/network/nsd_lan_discovery_gateway.dart';
import '../data/network/tcp_lan_transport_gateway.dart';
import '../data/preferences/shared_preferences_session_store.dart';
import '../data/security/flutter_secure_budget_transport_secret_store.dart';
import '../data/security/flutter_secure_identity_key_store.dart';
import '../data/security/secure_invite_consumption_store.dart';
import '../data/repositories/drift_account_repository.dart';
import '../data/repositories/drift_budget_repository.dart';
import '../data/repositories/drift_category_repository.dart';
import '../data/repositories/drift_dashboard_repository.dart';
import '../data/repositories/drift_extended_report_repository.dart';
import '../data/repositories/drift_identity_repository.dart';
import '../data/repositories/drift_invitation_repository.dart';
import '../data/repositories/drift_membership_repository.dart';
import '../data/repositories/drift_monthly_report_repository.dart';
import '../data/repositories/drift_plan_repository.dart';
import '../data/repositories/drift_report_export_repository.dart';
import '../data/repositories/drift_sync_journal.dart';
import '../data/repositories/drift_transaction_repository.dart';
import '../data/repositories/syncing_account_repository.dart';
import '../data/repositories/syncing_category_repository.dart';
import '../data/repositories/syncing_plan_repository.dart';
import '../data/repositories/syncing_membership_repository.dart';
import '../data/repositories/syncing_transaction_repository.dart';
import '../data/services/ed25519_identity_key_pair_generator.dart';
import '../data/services/ed25519_identity_signature_service.dart';
import '../data/services/drift_sync_mutation_executor.dart';
import '../data/services/excel_report_document_encoder.dart';
import '../data/services/platform_invite_file_gateway.dart';
import '../data/services/platform_report_share_gateway.dart';
import '../data/services/random_secure_token_generator.dart';
import '../data/services/secure_id_generator.dart';

final class AppCompositionRoot {
  AppCompositionRoot._({required BudgetDal dal, required this.services})
    : _dal = dal;

  factory AppCompositionRoot.defaults() {
    final dal = BudgetDal.defaults();
    final budgetRepository = DriftBudgetRepository(dal.usersAndBudgets);
    final baseCategoryRepository = DriftCategoryRepository(
      dal.categoriesAndAccounts,
    );
    final baseAccountRepository = DriftAccountRepository(
      dal.categoriesAndAccounts,
    );
    final baseTransactionRepository = DriftTransactionRepository(
      dal.transactions,
    );
    final basePlanRepository = DriftPlanRepository(dal.plansAndReceipts);
    final dashboardRepository = DriftDashboardRepository(dal.reports);
    final monthlyReportRepository = DriftMonthlyReportRepository(dal.reports);
    final extendedReportRepository = DriftExtendedReportRepository(dal.reports);
    final reportExportRepository = DriftReportExportRepository(
      dal.transactions,
    );
    final identityRepository = DriftIdentityRepository(dal.usersAndBudgets);
    final invitationRepository = DriftInvitationRepository(dal.usersAndBudgets);
    final baseMembershipRepository = DriftMembershipRepository(dal.usersAndBudgets);
    final sessionStore = SharedPreferencesSessionStore();
    final identityKeyStore = FlutterSecureIdentityKeyStore();
    final identityKeyPairGenerator = Ed25519IdentityKeyPairGenerator();
    final identitySignatureService = Ed25519IdentitySignatureService(
      keyStore: identityKeyStore,
    );
    final inviteConsumptionStore = SecureInviteConsumptionStore();
    final transportSecretStore = FlutterSecureBudgetTransportSecretStore();
    const inviteFileGateway = PlatformInviteFileGateway();
    final secureTokenGenerator = RandomSecureTokenGenerator();
    final transportSecretManager = BudgetTransportSecretManager(
      store: transportSecretStore,
      tokenGenerator: secureTokenGenerator,
    );
    const lanDiscoveryGateway = NsdLanDiscoveryGateway();
    const lanTransportGateway = TcpLanTransportGateway();
    const lanLocalAddressResolver = IoLanLocalAddressResolver();
    final lanDiscoveryTokenService = LanDiscoveryTokenService(
      transportSecretManager: transportSecretManager,
    );
    final lanHandshakeService = LanHandshakeService(
      transportSecretManager: transportSecretManager,
      signatureService: identitySignatureService,
      tokenGenerator: secureTokenGenerator,
      identityRepository: identityRepository,
    );
    final lanSecureSessionService = LanSecureSessionService(
      handshakeService: lanHandshakeService,
      sessionCrypto: LanSessionCrypto(),
      transportSecretManager: transportSecretManager,
    );
    final idGenerator = SecureIdGenerator();
    final ensureLocalIdentity = EnsureLocalIdentity(
      identityRepository: identityRepository,
      keyStore: identityKeyStore,
      keyPairGenerator: identityKeyPairGenerator,
      idGenerator: idGenerator,
    );
    final authorization = AuthorizeBudgetAction(
      membershipRepository: baseMembershipRepository,
      sessionStore: sessionStore,
    );
    final getPublicIdentity = GetPublicIdentity(ensureLocalIdentity);
    final syncJournal = DriftSyncJournal(
      database: dal.database,
      syncDao: dal.sync,
      identityRepository: identityRepository,
      signatureService: identitySignatureService,
    );
    final syncSessions = SyncSessionService(journal: syncJournal);
    final lanPeerSessions = LanPeerSessionManager(
      authorization: authorization,
      getPublicIdentity: getPublicIdentity,
      discovery: lanDiscoveryGateway,
      transport: lanTransportGateway,
      secureSession: lanSecureSessionService,
      discoveryTokenService: lanDiscoveryTokenService,
      localAddressResolver: lanLocalAddressResolver,
    );
    final syncMutationExecutor = DriftSyncMutationExecutor(
      database: dal.database,
      syncDao: dal.sync,
      idGenerator: idGenerator,
      signatureService: identitySignatureService,
    );
    final syncMutationContext = SessionSyncMutationContextProvider(
      sessionStore: sessionStore,
      getPublicIdentity: getPublicIdentity,
    );
    final categoryRepository = SyncingCategoryRepository(
      delegate: baseCategoryRepository,
      executor: syncMutationExecutor,
      contextProvider: syncMutationContext,
    );
    final accountRepository = SyncingAccountRepository(
      delegate: baseAccountRepository,
      executor: syncMutationExecutor,
      contextProvider: syncMutationContext,
    );
    final transactionRepository = SyncingTransactionRepository(
      delegate: baseTransactionRepository,
      executor: syncMutationExecutor,
      contextProvider: syncMutationContext,
    );
    final planRepository = SyncingPlanRepository(
      delegate: basePlanRepository,
      executor: syncMutationExecutor,
      contextProvider: syncMutationContext,
    );
    final membershipRepository = SyncingMembershipRepository(
      delegate: baseMembershipRepository,
      executor: syncMutationExecutor,
      contextProvider: syncMutationContext,
    );
    final inspectBudgetInvite = InspectBudgetInvite(
      signatureService: identitySignatureService,
      consumptionStore: inviteConsumptionStore,
    );
    final requireAccountInBudget = RequireAccountInBudget(accountRepository);
    final requireCategoryInBudget = RequireCategoryInBudget(categoryRepository);

    return AppCompositionRoot._(
      dal: dal,
      services: AppServices(
        acceptBudgetInvite: AcceptBudgetInvite(
          inspectInvite: inspectBudgetInvite,
          invitationRepository: invitationRepository,
          consumptionStore: inviteConsumptionStore,
          sessionStore: sessionStore,
          getPublicIdentity: getPublicIdentity,
          transportSecretManager: transportSecretManager,
        ),
        applyCategoryTemplates: ApplyCategoryTemplates(
          repository: categoryRepository,
          authorization: authorization,
        ),
        archiveAccount: ArchiveAccount(
          repository: accountRepository,
          authorization: authorization,
        ),
        archiveCategory: ArchiveCategory(
          repository: categoryRepository,
          authorization: authorization,
        ),
        canPerformBudgetAction: CanPerformBudgetAction(authorization),
        createAccount: CreateAccount(
          accountRepository: accountRepository,
          idGenerator: idGenerator,
          authorization: authorization,
        ),
        createBudgetInvite: CreateBudgetInvite(
          invitationRepository: invitationRepository,
          authorization: authorization,
          getPublicIdentity: getPublicIdentity,
          signatureService: identitySignatureService,
          tokenGenerator: secureTokenGenerator,
          transportSecretManager: transportSecretManager,
          idGenerator: idGenerator,
        ),
        createCategory: CreateCategory(
          categoryRepository: categoryRepository,
          idGenerator: idGenerator,
          authorization: authorization,
        ),
        createInitialBudget: CreateInitialBudget(
          budgetRepository: budgetRepository,
          categoryRepository: categoryRepository,
          sessionStore: sessionStore,
          idGenerator: idGenerator,
          identityKeyStore: identityKeyStore,
          identityKeyPairGenerator: identityKeyPairGenerator,
        ),
        createTransaction: CreateTransaction(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          requireCategoryInBudget: requireCategoryInBudget,
          idGenerator: idGenerator,
          authorization: authorization,
        ),
        createTransfer: CreateTransfer(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          idGenerator: idGenerator,
          authorization: authorization,
        ),
        deleteTransaction: DeleteTransaction(
          repository: transactionRepository,
          authorization: authorization,
        ),
        exportReport: ExportReport(
          reportRepository: extendedReportRepository,
          exportRepository: reportExportRepository,
          encoder: const ExcelReportDocumentEncoder(),
          shareGateway: const PlatformReportShareGateway(),
          authorization: authorization,
        ),
        getAccountBalance: GetAccountBalance(accountRepository),
        getBudgetAccountBalances: GetBudgetAccountBalances(accountRepository),
        getPublicIdentity: getPublicIdentity,
        inspectBudgetInvite: inspectBudgetInvite,
        lanPeerSessions: lanPeerSessions,
        syncSessions: syncSessions,
        pickBudgetInviteFile: PickBudgetInviteFile(inviteFileGateway),
        renameCategory: RenameCategory(
          repository: categoryRepository,
          authorization: authorization,
        ),
        requireAccountInBudget: requireAccountInBudget,
        requireCategoryInBudget: requireCategoryInBudget,
        resolveAppStartup: ResolveAppStartup(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
          ensureLocalIdentity: ensureLocalIdentity,
        ),
        selectBudget: SelectBudget(
          budgetRepository: budgetRepository,
          sessionStore: sessionStore,
        ),
        shareBudgetInviteFile: ShareBudgetInviteFile(inviteFileGateway),
        setMonthlyPlanAmount: SetMonthlyPlanAmount(
          planRepository: planRepository,
          categoryRepository: categoryRepository,
          idGenerator: idGenerator,
          authorization: authorization,
        ),
        updateAccount: UpdateAccount(
          repository: accountRepository,
          authorization: authorization,
        ),
        updateMemberRole: UpdateMemberRole(
          membershipRepository: membershipRepository,
          authorization: authorization,
        ),
        updateTransaction: UpdateTransaction(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          requireCategoryInBudget: requireCategoryInBudget,
          authorization: authorization,
        ),
        updateTransfer: UpdateTransfer(
          transactionRepository: transactionRepository,
          requireAccountInBudget: requireAccountInBudget,
          authorization: authorization,
        ),
        watchBudgetAccounts: WatchBudgetAccounts(accountRepository),
        watchBudgetCategories: WatchBudgetCategories(categoryRepository),
        watchDashboardSummary: WatchDashboardSummary(dashboardRepository),
        watchFilteredTransactions: WatchFilteredTransactions(
          transactionRepository,
        ),
        watchMonthlyPlan: WatchMonthlyPlan(planRepository),
        watchMonthlyReport: WatchMonthlyReport(monthlyReportRepository),
        watchBudgetMembers: WatchBudgetMembers(membershipRepository),
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

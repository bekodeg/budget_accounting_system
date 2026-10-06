import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/application/app_services.dart';
import 'package:budget_accounting_system/src/application/authorization/budget_action.dart';
import 'package:budget_accounting_system/src/application/authorization/budget_authorization_guard.dart';
import 'package:budget_accounting_system/src/application/errors/authorization_error.dart';
import 'package:budget_accounting_system/src/application/ports/budget_transport_secret_store.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/identity_key_pair_generator.dart';
import 'package:budget_accounting_system/src/application/ports/identity_key_store.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/application/ports/invite_consumption_store.dart';
import 'package:budget_accounting_system/src/application/ports/invite_file_gateway.dart';
import 'package:budget_accounting_system/src/application/ports/secure_token_generator.dart';
import 'package:budget_accounting_system/src/application/ports/session_store.dart';
import 'package:budget_accounting_system/src/application/ports/report_document_encoder.dart';
import 'package:budget_accounting_system/src/application/ports/report_share_gateway.dart';
import 'package:budget_accounting_system/src/application/services/budget_transport_secret_manager.dart';
import 'package:budget_accounting_system/src/application/use_cases/accept_budget_invite.dart';
import 'package:budget_accounting_system/src/application/use_cases/apply_category_templates.dart';
import 'package:budget_accounting_system/src/application/use_cases/archive_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/archive_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/can_perform_budget_action.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_budget_invite.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_initial_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_transfer.dart';
import 'package:budget_accounting_system/src/application/use_cases/delete_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/export_report.dart';
import 'package:budget_accounting_system/src/application/use_cases/ensure_local_identity.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_account_balance.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_budget_account_balances.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_public_identity.dart';
import 'package:budget_accounting_system/src/application/use_cases/inspect_budget_invite.dart';
import 'package:budget_accounting_system/src/application/use_cases/join_budget_from_invite.dart';
import 'package:budget_accounting_system/src/application/use_cases/pick_budget_invite_file.dart';
import 'package:budget_accounting_system/src/application/use_cases/rename_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_category_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/resolve_app_startup.dart';
import 'package:budget_accounting_system/src/application/use_cases/select_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/share_budget_invite_file.dart';
import 'package:budget_accounting_system/src/application/use_cases/set_monthly_plan_amount.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_member_role.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_transfer.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_budget_accounts.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_budget_categories.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_dashboard_summary.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_filtered_transactions.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_monthly_plan.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_monthly_report.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_budget_members.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_period_report.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_year_report.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_transactions.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_user_budgets.dart';
import 'package:budget_accounting_system/src/domain/models/account_balance.dart';
import 'package:budget_accounting_system/src/domain/models/app_session.dart';
import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/budget_invite.dart';
import 'package:budget_accounting_system/src/domain/models/budget_transaction_entry.dart';
import 'package:budget_accounting_system/src/domain/models/category_template.dart';
import 'package:budget_accounting_system/src/domain/models/dashboard_summary.dart';
import 'package:budget_accounting_system/src/domain/models/initial_budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/local_device.dart';
import 'package:budget_accounting_system/src/domain/models/monthly_plan.dart';
import 'package:budget_accounting_system/src/domain/models/monthly_report.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/period_report.dart';
import 'package:budget_accounting_system/src/domain/models/public_identity.dart';
import 'package:budget_accounting_system/src/domain/models/report_export.dart';
import 'package:budget_accounting_system/src/domain/models/report_filter.dart';
import 'package:budget_accounting_system/src/domain/models/year_report.dart';
import 'package:budget_accounting_system/src/domain/models/transaction_filter.dart';
import 'package:budget_accounting_system/src/domain/repositories/account_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/budget_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/category_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/dashboard_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/plan_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/report_export_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/monthly_report_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/extended_report_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/identity_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/fresh_invitation_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/invitation_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/membership_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/transaction_repository.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';

AppServices fakeAppServices({
  required FakeBudgetRepository repository,
  required FakeSessionStore sessionStore,
  FakeCategoryRepository? categoryRepository,
  FakeAccountRepository? accountRepository,
  FakeTransactionRepository? transactionRepository,
  FakeDashboardRepository? dashboardRepository,
  FakePlanRepository? planRepository,
  FakeMonthlyReportRepository? monthlyReportRepository,
  FakeExtendedReportRepository? extendedReportRepository,
  FakeIdentityRepository? identityRepository,
  FakeIdentityKeyStore? identityKeyStore,
  FakeIdentityKeyPairGenerator? identityKeyPairGenerator,
  FakeMembershipRepository? membershipRepository,
  FakeInvitationRepository? invitationRepository,
  FakeIdentitySignatureService? identitySignatureService,
  FakeInviteConsumptionStore? inviteConsumptionStore,
  FakeInviteFileGateway? inviteFileGateway,
  FakeSecureTokenGenerator? secureTokenGenerator,
  FakeBudgetTransportSecretStore? transportSecretStore,
  BudgetAuthorizationGuard? authorization,
  FakeIdGenerator? idGenerator,
}) {
  final categories = categoryRepository ?? FakeCategoryRepository();
  final accounts = accountRepository ?? FakeAccountRepository();
  final transactions = transactionRepository ?? FakeTransactionRepository();
  final dashboard = dashboardRepository ?? FakeDashboardRepository();
  final plans = planRepository ?? FakePlanRepository();
  final monthlyReports =
      monthlyReportRepository ?? FakeMonthlyReportRepository();
  final extendedReports =
      extendedReportRepository ?? FakeExtendedReportRepository();
  final identities = identityRepository ?? FakeIdentityRepository();
  final identityKeys = identityKeyStore ?? FakeIdentityKeyStore();
  final identityGenerator =
      identityKeyPairGenerator ?? FakeIdentityKeyPairGenerator();
  final memberships = membershipRepository ?? FakeMembershipRepository();
  final invitations =
      invitationRepository ??
          FakeInvitationRepository(budgetRepository: repository);
  final signatures = identitySignatureService ?? FakeIdentitySignatureService();
  final inviteConsumption =
      inviteConsumptionStore ?? FakeInviteConsumptionStore();
  final inviteFiles = inviteFileGateway ?? FakeInviteFileGateway();
  final tokens = secureTokenGenerator ?? FakeSecureTokenGenerator();
  final transportSecrets =
      transportSecretStore ?? FakeBudgetTransportSecretStore();
  final transportSecretManager = BudgetTransportSecretManager(
    store: transportSecrets,
    tokenGenerator: tokens,
  );
  final auth = authorization ?? FakeBudgetAuthorizationGuard();
  final ids =
      idGenerator ??
      FakeIdGenerator([
        'user-1',
        'budget-1',
        'device-1',
        'entity-1',
        'entity-2',
      ]);
  final ensureLocalIdentity = EnsureLocalIdentity(
    identityRepository: identities,
    keyStore: identityKeys,
    keyPairGenerator: identityGenerator,
    idGenerator: ids,
  );

  final getPublicIdentity = GetPublicIdentity(ensureLocalIdentity);
  final inspectInvite = InspectBudgetInvite(
    signatureService: signatures,
    consumptionStore: inviteConsumption,
  );

  return AppServices(
    acceptBudgetInvite: AcceptBudgetInvite(
      inspectInvite: inspectInvite,
      invitationRepository: invitations,
      consumptionStore: inviteConsumption,
      sessionStore: sessionStore,
      getPublicIdentity: getPublicIdentity,
      transportSecretManager: transportSecretManager,
    ),
    applyCategoryTemplates: ApplyCategoryTemplates(
      repository: categories,
      authorization: auth,
    ),
    archiveAccount: ArchiveAccount(repository: accounts, authorization: auth),
    archiveCategory: ArchiveCategory(
      repository: categories,
      authorization: auth,
    ),
    canPerformBudgetAction: CanPerformBudgetAction(auth),
    createAccount: CreateAccount(
      accountRepository: accounts,
      idGenerator: ids,
      authorization: auth,
    ),
    createBudgetInvite: CreateBudgetInvite(
      invitationRepository: invitations,
      authorization: auth,
      getPublicIdentity: getPublicIdentity,
      signatureService: signatures,
      tokenGenerator: tokens,
      transportSecretManager: transportSecretManager,
      idGenerator: ids,
    ),
    createCategory: CreateCategory(
      categoryRepository: categories,
      idGenerator: ids,
      authorization: auth,
    ),
    createTransfer: CreateTransfer(
      transactionRepository: transactions,
      requireAccountInBudget: RequireAccountInBudget(accounts),
      idGenerator: ids,
      authorization: auth,
    ),
    createTransaction: CreateTransaction(
      transactionRepository: transactions,
      requireAccountInBudget: RequireAccountInBudget(accounts),
      requireCategoryInBudget: RequireCategoryInBudget(categories),
      idGenerator: ids,
      authorization: auth,
    ),
    deleteTransaction: DeleteTransaction(
      repository: transactions,
      authorization: auth,
    ),
    exportReport: ExportReport(
      reportRepository: extendedReports,
      exportRepository: FakeReportExportRepository(),
      encoder: FakeReportDocumentEncoder(),
      shareGateway: FakeReportShareGateway(),
      authorization: auth,
    ),
    createInitialBudget: CreateInitialBudget(
      budgetRepository: repository,
      categoryRepository: categories,
      sessionStore: sessionStore,
      idGenerator: ids,
      identityKeyStore: identityKeys,
      identityKeyPairGenerator: identityGenerator,
    ),
    getAccountBalance: GetAccountBalance(accounts),
    getBudgetAccountBalances: GetBudgetAccountBalances(accounts),
    getPublicIdentity: getPublicIdentity,
    inspectBudgetInvite: inspectInvite,
    joinBudgetFromInvite: JoinBudgetFromInvite(
      inspectInvite: inspectInvite,
      invitationRepository: invitations,
      consumptionStore: inviteConsumption,
      sessionStore: sessionStore,
      transportSecretManager: transportSecretManager,
      idGenerator: ids,
      identityKeyStore: identityKeys,
      identityKeyPairGenerator: identityGenerator,
    ),
    pickBudgetInviteFile: PickBudgetInviteFile(inviteFiles),
    renameCategory: RenameCategory(repository: categories, authorization: auth),
    requireAccountInBudget: RequireAccountInBudget(accounts),
    requireCategoryInBudget: RequireCategoryInBudget(categories),
    resolveAppStartup: ResolveAppStartup(
      budgetRepository: repository,
      sessionStore: sessionStore,
    ),
    selectBudget: SelectBudget(
      budgetRepository: repository,
      sessionStore: sessionStore,
    ),
    shareBudgetInviteFile: ShareBudgetInviteFile(inviteFiles),
    setMonthlyPlanAmount: SetMonthlyPlanAmount(
      planRepository: plans,
      categoryRepository: categories,
      idGenerator: ids,
      authorization: auth,
    ),
    updateAccount: UpdateAccount(repository: accounts, authorization: auth),
    updateMemberRole: UpdateMemberRole(
      membershipRepository: memberships,
      authorization: auth,
    ),
    updateTransfer: UpdateTransfer(
      transactionRepository: transactions,
      requireAccountInBudget: RequireAccountInBudget(accounts),
      authorization: auth,
    ),
    updateTransaction: UpdateTransaction(
      transactionRepository: transactions,
      requireAccountInBudget: RequireAccountInBudget(accounts),
      requireCategoryInBudget: RequireCategoryInBudget(categories),
      authorization: auth,
    ),
    watchBudgetAccounts: WatchBudgetAccounts(accounts),
    watchBudgetCategories: WatchBudgetCategories(categories),
    watchDashboardSummary: WatchDashboardSummary(dashboard),
    watchFilteredTransactions: WatchFilteredTransactions(transactions),
    watchMonthlyPlan: WatchMonthlyPlan(plans),
    watchMonthlyReport: WatchMonthlyReport(monthlyReports),
    watchBudgetMembers: WatchBudgetMembers(memberships),
    watchPeriodReport: WatchPeriodReport(extendedReports),
    watchYearReport: WatchYearReport(extendedReports),
    watchTransactions: WatchTransactions(transactions),
    watchUserBudgets: WatchUserBudgets(repository),
  );
}

final class FakeIdentitySignatureService implements IdentitySignatureService {
  @override
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  }) async {
    return base64Url.encode(message);
  }

  @override
  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  }) async {
    return signature == base64Url.encode(message);
  }
}

final class FakeBudgetTransportSecretStore
    implements BudgetTransportSecretStore {
  final Map<String, String> secretsByBudget = {};

  @override
  Future<String?> load(String budgetId) async => secretsByBudget[budgetId];

  @override
  Future<void> save({required String budgetId, required String secret}) async {
    secretsByBudget[budgetId] = secret;
  }

  @override
  Future<void> delete(String budgetId) async {
    secretsByBudget.remove(budgetId);
  }
}

final class FakeInviteConsumptionStore implements InviteConsumptionStore {
  final Set<String> consumed = {};

  @override
  Future<bool> isConsumed(String inviteId) async => consumed.contains(inviteId);

  @override
  Future<void> markConsumed(String inviteId) async {
    consumed.add(inviteId);
  }

  @override
  Future<void> unmarkConsumed(String inviteId) async {
    consumed.remove(inviteId);
  }
}

final class FakeInviteFileGateway implements InviteFileGateway {
  String? pickedPayload;
  String? sharedFileName;
  String? sharedPayload;

  @override
  Future<String?> pick() async => pickedPayload;

  @override
  Future<void> share({
    required String fileName,
    required String payload,
  }) async {
    sharedFileName = fileName;
    sharedPayload = payload;
  }
}

final class FakeSecureTokenGenerator implements SecureTokenGenerator {
  int _counter = 0;

  @override
  String nextToken({int bytes = 32}) {
    _counter += 1;
    return 'token-$bytes-$_counter';
  }
}

final class FakeInvitationRepository
    implements InvitationRepository, FreshInvitationRepository {
  FakeInvitationRepository({
    Map<String, BudgetSummary>? budgets,
    this.budgetRepository,
    this.acceptNewIdentityError,
  }) : budgets =
          budgets ??
          {
            'budget-1': const BudgetSummary(
              id: 'budget-1',
              name: 'Test budget',
              baseCurrency: 'EUR',
            ),
          };

  final Map<String, BudgetSummary> budgets;
  final FakeBudgetRepository? budgetRepository;
  final Object? acceptNewIdentityError;
  final List<({BudgetInvite invite, PublicIdentity joiningIdentity})> accepted =
      [];

  @override
  Future<BudgetSummary?> findBudget(String budgetId) async => budgets[budgetId];

  @override
  Future<void> acceptInvite({
    required BudgetInvite invite,
    required PublicIdentity joiningIdentity,
  }) async {
    _accept(invite, joiningIdentity);
  }

  @override
  Future<void> acceptInviteForNewIdentity({
    required BudgetInvite invite,
    required String joiningUserName,
    required PublicIdentity joiningIdentity,
  }) async {
    final error = acceptNewIdentityError;
    if (error != null) {
      throw error;
    }
    _accept(invite, joiningIdentity);
    final repository = budgetRepository;
    if (repository != null) {
      repository.firstUserId ??= joiningIdentity.userId;
      repository.budgetsByUser[joiningIdentity.userId] = [
        BudgetSummary(
          id: invite.budgetId,
          name: invite.budgetName,
          baseCurrency: invite.baseCurrency,
        ),
      ];
    }
  }

  void _accept(BudgetInvite invite, PublicIdentity joiningIdentity) {
    accepted.add((invite: invite, joiningIdentity: joiningIdentity));
    budgets.putIfAbsent(
      invite.budgetId,
      () => BudgetSummary(
        id: invite.budgetId,
        name: invite.budgetName,
        baseCurrency: invite.baseCurrency,
      ),
    );
  }
}

final class FakeBudgetAuthorizationGuard implements BudgetAuthorizationGuard {
  FakeBudgetAuthorizationGuard({
    this.userId = 'user-1',
    this.role = MemberRole.owner,
  });

  final String userId;
  final MemberRole role;
  final List<BudgetAction> calls = [];

  @override
  Future<BudgetMemberProfile> require({
    required String budgetId,
    required BudgetAction action,
  }) async {
    calls.add(action);
    final allowed = switch (role) {
      MemberRole.owner => true,
      MemberRole.editor => action != BudgetAction.manageMembers,
      MemberRole.viewer =>
        action == BudgetAction.read || action == BudgetAction.export,
    };
    if (!allowed) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.forbidden,
        message: 'Action is forbidden for the fake role.',
      );
    }
    return BudgetMemberProfile(
      userId: userId,
      name: 'Test User',
      role: role,
      joinedAt: DateTime(2026, 1, 1),
      revokedAt: null,
    );
  }
}

final class FakeMembershipRepository implements MembershipRepository {
  FakeMembershipRepository({
    Map<String, List<BudgetMemberProfile>>? membersByBudget,
  }) : membersByBudget = membersByBudget ?? {};

  final Map<String, List<BudgetMemberProfile>> membersByBudget;
  final StreamController<String> _changes = StreamController.broadcast();

  List<BudgetMemberProfile> snapshot(String budgetId) =>
      List.unmodifiable(membersByBudget[budgetId] ?? const []);

  void _emit(String budgetId) => _changes.add(budgetId);

  @override
  Future<BudgetMemberProfile?> findActiveMember({
    required String budgetId,
    required String userId,
  }) async {
    for (final member in membersByBudget[budgetId] ?? const []) {
      if (member.userId == userId && member.isActive) return member;
    }
    return null;
  }

  @override
  Stream<List<BudgetMemberProfile>> watchMembers(String budgetId) async* {
    yield snapshot(budgetId);
    await for (final changedBudgetId in _changes.stream) {
      if (changedBudgetId == budgetId) yield snapshot(budgetId);
    }
  }

  @override
  Future<int> countActiveOwners(String budgetId) async {
    return (membersByBudget[budgetId] ?? const [])
        .where((member) => member.isActive && member.role == MemberRole.owner)
        .length;
  }

  @override
  Future<bool> updateMemberRole({
    required String budgetId,
    required String userId,
    required MemberRole role,
  }) async {
    final members = membersByBudget[budgetId];
    if (members == null) return false;
    final index = members.indexWhere(
      (member) => member.userId == userId && member.isActive,
    );
    if (index < 0) return false;
    members[index] = members[index].copyWith(role: role);
    _emit(budgetId);
    return true;
  }
}

final class FakeIdentityKeyStore implements IdentityKeyStore {
  final Map<String, String> deviceByUser = {};
  final Map<String, String> privateKeyByDevice = {};

  @override
  Future<String?> loadCurrentDeviceId(String userId) async {
    return deviceByUser[userId];
  }

  @override
  Future<String?> loadPrivateKey(String deviceId) async {
    return privateKeyByDevice[deviceId];
  }

  @override
  Future<void> saveIdentity({
    required String userId,
    required String deviceId,
    required String privateKey,
  }) async {
    deviceByUser[userId] = deviceId;
    privateKeyByDevice[deviceId] = privateKey;
  }

  @override
  Future<void> deleteIdentity({
    required String userId,
    required String deviceId,
  }) async {
    privateKeyByDevice.remove(deviceId);
    if (deviceByUser[userId] == deviceId) {
      deviceByUser.remove(userId);
    }
  }
}

final class FakeIdentityKeyPairGenerator implements IdentityKeyPairGenerator {
  FakeIdentityKeyPairGenerator({
    this.publicKey = 'ed25519:public-test-key',
    this.privateKey = 'private-test-key',
  });

  final String publicKey;
  final String privateKey;

  @override
  Future<GeneratedIdentityKeyPair> generate() async {
    return GeneratedIdentityKeyPair(
      publicKey: publicKey,
      privateKey: privateKey,
    );
  }

  @override
  Future<String> publicKeyFromPrivate(String privateKey) async {
    if (privateKey != this.privateKey) {
      return 'ed25519:mismatch';
    }
    return publicKey;
  }
}

final class FakeIdentityRepository implements IdentityRepository {
  FakeIdentityRepository({
    Map<String, String>? publicKeysByUser,
    Map<String, LocalDevice>? devicesById,
  }) : publicKeysByUser = publicKeysByUser ?? {},
       devicesById = devicesById ?? {};

  final Map<String, String> publicKeysByUser;
  final Map<String, LocalDevice> devicesById;

  @override
  Future<String?> getUserPublicKey(String userId) async {
    return publicKeysByUser[userId] ?? 'local-unverified:$userId';
  }

  @override
  Future<LocalDevice?> findDevice(String deviceId) async {
    return devicesById[deviceId];
  }

  @override
  Future<void> migrateLegacyIdentity({
    required String userId,
    required String publicKey,
    required String deviceId,
  }) async {
    publicKeysByUser[userId] = publicKey;
    devicesById[deviceId] = LocalDevice(
      id: deviceId,
      userId: userId,
      revokedAt: null,
    );
  }
}

final class FakeReportExportRepository implements ReportExportRepository {
  @override
  Future<List<ReportExportTransaction>> listTransactions(
    ReportFilter filter,
  ) async {
    return const [];
  }
}

final class FakeReportDocumentEncoder implements ReportDocumentEncoder {
  @override
  Uint8List encodeCsv(ReportExportBundle bundle) => Uint8List(0);

  @override
  Uint8List encodeXlsx(ReportExportBundle bundle) => Uint8List(0);
}

final class FakeReportShareGateway implements ReportShareGateway {
  @override
  Future<ReportExportResult> share({
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  }) async {
    return ReportExportResult(
      csvFileName: '$baseName.csv',
      xlsxFileName: '$baseName.xlsx',
    );
  }
}

final class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository({
    Map<String, List<BudgetSummary>>? budgetsByUser,
    this.firstUserId,
    this.createError,
  }) : budgetsByUser = budgetsByUser ?? {};

  final Map<String, List<BudgetSummary>> budgetsByUser;
  String? firstUserId;
  Object? createError;

  String? createdUserId;
  String? createdUserName;
  String? createdPublicKey;
  String? createdDeviceId;
  String? createdBudgetId;
  String? createdBudgetName;
  Currency? createdCurrency;
  List<InitialBudgetCategory> createdInitialCategories = const [];

  @override
  Future<AppSession> createOwnedBudget({
    required String userId,
    required String userName,
    required String publicKey,
    required String deviceId,
    required String budgetId,
    required String budgetName,
    required Currency baseCurrency,
    List<InitialBudgetCategory> initialCategories = const [],
  }) async {
    final error = createError;
    if (error != null) {
      throw error;
    }

    createdUserId = userId;
    createdUserName = userName;
    createdPublicKey = publicKey;
    createdDeviceId = deviceId;
    createdBudgetId = budgetId;
    createdBudgetName = budgetName;
    createdCurrency = baseCurrency;
    createdInitialCategories = List.unmodifiable(initialCategories);

    firstUserId ??= userId;
    budgetsByUser[userId] = [
      ...(budgetsByUser[userId] ?? const []),
      BudgetSummary(
        id: budgetId,
        name: budgetName,
        baseCurrency: baseCurrency.code,
      ),
    ];

    return AppSession(userId: userId, budgetId: budgetId);
  }

  @override
  Future<String?> findFirstUserIdWithBudget() async => firstUserId;

  @override
  Future<List<BudgetSummary>> getBudgetsForUser(String userId) async {
    return List<BudgetSummary>.unmodifiable(budgetsByUser[userId] ?? const []);
  }

  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    return Stream.value(
      List<BudgetSummary>.unmodifiable(budgetsByUser[userId] ?? const []),
    );
  }
}

final class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository({
    List<CategoryTemplate>? templates,
    Map<String, List<BudgetCategory>>? categoriesByBudget,
  }) : templates = templates ?? const [],
       categoriesByBudget = categoriesByBudget ?? {};

  final List<CategoryTemplate> templates;
  final Map<String, List<BudgetCategory>> categoriesByBudget;
  final StreamController<String> _changes = StreamController.broadcast();

  List<BudgetCategory> snapshot(
    String budgetId, {
    required bool includeArchived,
  }) {
    final categories = categoriesByBudget[budgetId] ?? const [];
    return List.unmodifiable(
      categories
          .where((category) => includeArchived || !category.isArchived)
          .toList(growable: false),
    );
  }

  void _emit(String budgetId) {
    _changes.add(budgetId);
  }

  @override
  Stream<List<BudgetCategory>> watchCategories(
    String budgetId, {
    required bool includeArchived,
  }) async* {
    yield snapshot(budgetId, includeArchived: includeArchived);
    await for (final changedBudgetId in _changes.stream) {
      if (changedBudgetId == budgetId) {
        yield snapshot(budgetId, includeArchived: includeArchived);
      }
    }
  }

  @override
  Future<BudgetCategory?> findCategory({
    required String budgetId,
    required String categoryId,
  }) async {
    for (final category in categoriesByBudget[budgetId] ?? const []) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  @override
  Future<List<CategoryTemplate>> getTemplates() async {
    return List.unmodifiable(templates);
  }

  @override
  Future<void> insertCategoriesIfMissing(
    List<BudgetCategory> categories,
  ) async {
    for (final category in categories) {
      final current = categoriesByBudget.putIfAbsent(
        category.budgetId,
        () => [],
      );
      if (current.every((existing) => existing.id != category.id)) {
        current.add(category);
        _emit(category.budgetId);
      }
    }
  }

  @override
  Future<void> createCategory(BudgetCategory category) async {
    categoriesByBudget.putIfAbsent(category.budgetId, () => []).add(category);
    _emit(category.budgetId);
  }

  @override
  Future<void> renameCategory({
    required String budgetId,
    required String categoryId,
    required String name,
  }) async {
    final categories = categoriesByBudget[budgetId];
    if (categories == null) return;
    final index = categories.indexWhere(
      (category) => category.id == categoryId,
    );
    if (index >= 0) {
      categories[index] = categories[index].copyWith(name: name);
      _emit(budgetId);
    }
  }

  @override
  Future<void> setCategoryArchived({
    required String budgetId,
    required String categoryId,
    required bool isArchived,
  }) async {
    final categories = categoriesByBudget[budgetId];
    if (categories == null) return;
    final index = categories.indexWhere(
      (category) => category.id == categoryId,
    );
    if (index >= 0) {
      categories[index] = categories[index].copyWith(isArchived: isArchived);
      _emit(budgetId);
    }
  }
}

final class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    Map<String, List<BudgetAccount>>? accountsByBudget,
    Map<String, BigInt>? transactionDeltaByAccount,
    Set<String>? accountsWithTransactions,
  }) : accountsByBudget = accountsByBudget ?? {},
       transactionDeltaByAccount = transactionDeltaByAccount ?? {},
       accountsWithTransactions = accountsWithTransactions ?? {};

  final Map<String, List<BudgetAccount>> accountsByBudget;
  final Map<String, BigInt> transactionDeltaByAccount;
  final Set<String> accountsWithTransactions;
  final StreamController<String> _changes = StreamController.broadcast();

  List<BudgetAccount> snapshot(
    String budgetId, {
    required bool includeArchived,
  }) {
    final accounts = accountsByBudget[budgetId] ?? const [];
    return List.unmodifiable(
      accounts
          .where((account) => includeArchived || !account.isArchived)
          .toList(growable: false),
    );
  }

  void _emit(String budgetId) {
    _changes.add(budgetId);
  }

  @override
  Stream<List<BudgetAccount>> watchAccounts(
    String budgetId, {
    required bool includeArchived,
  }) async* {
    yield snapshot(budgetId, includeArchived: includeArchived);
    await for (final changedBudgetId in _changes.stream) {
      if (changedBudgetId == budgetId) {
        yield snapshot(budgetId, includeArchived: includeArchived);
      }
    }
  }

  @override
  Future<BudgetAccount?> findAccount({
    required String budgetId,
    required String accountId,
  }) async {
    for (final account in accountsByBudget[budgetId] ?? const []) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  @override
  Future<bool> hasTransactions({
    required String budgetId,
    required String accountId,
  }) async {
    final account = await findAccount(budgetId: budgetId, accountId: accountId);
    return account != null && accountsWithTransactions.contains(accountId);
  }

  @override
  Future<void> createAccount(BudgetAccount account) async {
    accountsByBudget.putIfAbsent(account.budgetId, () => []).add(account);
    _emit(account.budgetId);
  }

  @override
  Future<bool> updateAccount(BudgetAccount account) async {
    final accounts = accountsByBudget[account.budgetId];
    if (accounts == null) return false;
    final index = accounts.indexWhere((item) => item.id == account.id);
    if (index < 0) return false;
    accounts[index] = account;
    _emit(account.budgetId);
    return true;
  }

  @override
  Future<bool> setAccountArchived({
    required String budgetId,
    required String accountId,
    required bool isArchived,
  }) async {
    final accounts = accountsByBudget[budgetId];
    if (accounts == null) return false;
    final index = accounts.indexWhere((item) => item.id == accountId);
    if (index < 0) return false;
    accounts[index] = accounts[index].copyWith(isArchived: isArchived);
    _emit(budgetId);
    return true;
  }

  @override
  Future<AccountBalance?> getBalance({
    required String budgetId,
    required String accountId,
    DateTime? atInclusive,
  }) async {
    final account = await findAccount(budgetId: budgetId, accountId: accountId);
    if (account == null) return null;
    return AccountBalance(
      accountId: account.id,
      minorUnits:
          account.openingBalanceMinor +
          (transactionDeltaByAccount[account.id] ?? BigInt.zero),
      currency: account.currency,
    );
  }

  @override
  Future<List<AccountBalance>> getBalances({
    required String budgetId,
    required bool includeArchived,
    DateTime? atInclusive,
  }) async {
    final accounts = snapshot(budgetId, includeArchived: includeArchived);
    return [
      for (final account in accounts)
        AccountBalance(
          accountId: account.id,
          minorUnits:
              account.openingBalanceMinor +
              (transactionDeltaByAccount[account.id] ?? BigInt.zero),
          currency: account.currency,
        ),
    ];
  }
}

final class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({DashboardSummary? summary})
    : summary =
          summary ??
          DashboardSummary(
            monthStart: DateTime(2026, 9),
            incomeMinorByCurrency: const {},
            expenseMinorByCurrency: const {},
            balanceMinorByCurrency: const {},
          );

  DashboardSummary summary;
  final StreamController<DashboardSummary> _changes =
      StreamController.broadcast();

  void emit(DashboardSummary value) {
    summary = value;
    _changes.add(value);
  }

  @override
  Stream<DashboardSummary> watchSummary({
    required String budgetId,
    required DateTime monthStart,
  }) async* {
    yield summary;
    yield* _changes.stream;
  }
}

final class FakeExtendedReportRepository implements ExtendedReportRepository {
  FakeExtendedReportRepository({
    PeriodReport? periodReport,
    YearReport? yearReport,
  }) : periodReport =
           periodReport ??
           PeriodReport(
             fromInclusive: DateTime(2026, 9),
             toExclusive: DateTime(2026, 10),
             incomeMinorByCurrency: const {},
             expenseMinorByCurrency: const {},
             categories: const [],
           ),
       yearReport =
           yearReport ??
           YearReport(
             year: 2026,
             baseCurrency: 'EUR',
             months: [
               for (var month = 1; month <= 12; month++)
                 YearMonthReport(
                   monthStart: DateTime(2026, month),
                   incomeMinorByCurrency: const {},
                   expenseMinorByCurrency: const {},
                   plannedAmountMinor: BigInt.zero,
                   actualBaseCurrencyMinor: BigInt.zero,
                 ),
             ],
             categories: const [],
           );

  PeriodReport periodReport;
  YearReport yearReport;
  ReportFilter? lastPeriodFilter;
  final StreamController<PeriodReport> _periodChanges =
      StreamController<PeriodReport>.broadcast();
  final StreamController<YearReport> _yearChanges =
      StreamController<YearReport>.broadcast();

  void emitPeriod(PeriodReport value) {
    periodReport = value;
    _periodChanges.add(value);
  }

  void emitYear(YearReport value) {
    yearReport = value;
    _yearChanges.add(value);
  }

  @override
  Stream<PeriodReport> watchPeriodReport(ReportFilter filter) async* {
    lastPeriodFilter = filter;
    yield periodReport;
    yield* _periodChanges.stream;
  }

  @override
  Stream<YearReport> watchYearReport({
    required String budgetId,
    required int year,
  }) async* {
    yield yearReport;
    yield* _yearChanges.stream;
  }
}

final class FakeMonthlyReportRepository implements MonthlyReportRepository {
  FakeMonthlyReportRepository({MonthlyReport? report})
    : report =
          report ??
          MonthlyReport(
            monthStart: DateTime(2026, 9),
            baseCurrency: 'EUR',
            incomeMinorByCurrency: const {},
            expenseMinorByCurrency: const {},
            categories: const [],
            accountBalances: const [],
          );

  MonthlyReport report;
  final StreamController<MonthlyReport> _changes =
      StreamController<MonthlyReport>.broadcast();

  void emit(MonthlyReport value) {
    report = value;
    _changes.add(value);
  }

  @override
  Stream<MonthlyReport> watchMonthlyReport({
    required String budgetId,
    required DateTime monthStart,
  }) async* {
    yield report;
    yield* _changes.stream;
  }
}

final class FakePlanRepository implements PlanRepository {
  FakePlanRepository({Map<String, List<MonthlyPlan>>? plansByBudget})
    : plansByBudget = plansByBudget ?? {};

  final Map<String, List<MonthlyPlan>> plansByBudget;
  final StreamController<String> _changes = StreamController.broadcast();

  String _key(DateTime month) => '${month.year}-${month.month}';

  List<MonthlyPlan> snapshot(String budgetId, DateTime month) {
    final normalized = normalizePlanMonth(month);
    return List.unmodifiable(
      (plansByBudget[budgetId] ?? const [])
          .where((plan) => normalizePlanMonth(plan.month) == normalized)
          .toList(growable: false),
    );
  }

  void _emit(String budgetId) => _changes.add(budgetId);

  @override
  Stream<List<MonthlyPlan>> watchMonth({
    required String budgetId,
    required DateTime month,
  }) async* {
    yield snapshot(budgetId, month);
    await for (final changedBudgetId in _changes.stream) {
      if (changedBudgetId == budgetId) {
        yield snapshot(budgetId, month);
      }
    }
  }

  @override
  Future<void> upsert(MonthlyPlan plan) async {
    final items = plansByBudget.putIfAbsent(plan.budgetId, () => []);
    final index = items.indexWhere(
      (item) =>
          _key(item.month) == _key(plan.month) &&
          item.categoryId == plan.categoryId,
    );
    if (index < 0) {
      items.add(plan);
    } else {
      items[index] = MonthlyPlan(
        id: items[index].id,
        budgetId: plan.budgetId,
        month: normalizePlanMonth(plan.month),
        categoryId: plan.categoryId,
        plannedAmountMinor: plan.plannedAmountMinor,
        updatedAt: plan.updatedAt,
      );
    }
    _emit(plan.budgetId);
  }

  @override
  Future<void> clear({
    required String budgetId,
    required DateTime month,
    required String categoryId,
  }) async {
    final key = _key(month);
    plansByBudget[budgetId]?.removeWhere(
      (plan) => _key(plan.month) == key && plan.categoryId == categoryId,
    );
    _emit(budgetId);
  }
}

final class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository({
    Map<String, List<BudgetTransactionEntry>>? transactionsByBudget,
  }) : transactionsByBudget = transactionsByBudget ?? {};

  final Map<String, List<BudgetTransactionEntry>> transactionsByBudget;
  final StreamController<String> _changes = StreamController.broadcast();

  void _emit(String budgetId) => _changes.add(budgetId);

  List<BudgetTransactionEntry> snapshot(String budgetId) {
    final items = [...transactionsByBudget[budgetId] ?? const []]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(items);
  }

  @override
  Stream<List<BudgetTransactionEntry>> watchActiveTransactions(
    String budgetId,
  ) async* {
    yield snapshot(budgetId);
    await for (final changedBudgetId in _changes.stream) {
      if (changedBudgetId == budgetId) yield snapshot(budgetId);
    }
  }

  @override
  Stream<List<BudgetTransactionEntry>> watchFilteredTransactions(
    TransactionFilter filter,
  ) async* {
    List<BudgetTransactionEntry> apply() {
      return snapshot(filter.budgetId)
          .where((item) {
            if (filter.fromInclusive != null &&
                item.occurredAt.isBefore(filter.fromInclusive!)) {
              return false;
            }
            if (filter.toExclusive != null &&
                !item.occurredAt.isBefore(filter.toExclusive!)) {
              return false;
            }
            if (filter.type != null && item.type != filter.type) return false;
            if (filter.categoryId != null &&
                item.categoryId != filter.categoryId) {
              return false;
            }
            if (filter.accountId != null &&
                item.accountId != filter.accountId &&
                item.destinationAccountId != filter.accountId) {
              return false;
            }
            if (filter.authorId != null && item.authorId != filter.authorId) {
              return false;
            }
            return true;
          })
          .toList(growable: false);
    }

    yield apply();
    await for (final changedBudgetId in _changes.stream) {
      if (changedBudgetId == filter.budgetId) yield apply();
    }
  }

  @override
  Future<BudgetTransactionEntry?> findActiveTransaction({
    required String budgetId,
    required String transactionId,
  }) async {
    for (final item in transactionsByBudget[budgetId] ?? const []) {
      if (item.id == transactionId) return item;
    }
    return null;
  }

  @override
  Future<void> createTransaction(BudgetTransactionEntry transaction) async {
    transactionsByBudget
        .putIfAbsent(transaction.budgetId, () => [])
        .add(transaction);
    _emit(transaction.budgetId);
  }

  @override
  Future<bool> updateTransaction(BudgetTransactionEntry transaction) async {
    final items = transactionsByBudget[transaction.budgetId];
    if (items == null) return false;
    final index = items.indexWhere((item) => item.id == transaction.id);
    if (index < 0) return false;
    items[index] = transaction;
    _emit(transaction.budgetId);
    return true;
  }

  @override
  Future<bool> softDeleteTransaction({
    required String budgetId,
    required String transactionId,
    required DateTime deletedAt,
  }) async {
    final items = transactionsByBudget[budgetId];
    if (items == null) return false;
    final before = items.length;
    items.removeWhere((item) => item.id == transactionId);
    if (items.length == before) return false;
    _emit(budgetId);
    return true;
  }
}

final class FakeSessionStore implements SessionStore {
  FakeSessionStore({
    this.currentUserId,
    this.currentBudgetId,
    this.failSaveSession = false,
  });

  String? currentUserId;
  String? currentBudgetId;
  bool failSaveSession;

  @override
  Future<String?> loadCurrentUserId() async => currentUserId;

  @override
  Future<String?> loadCurrentBudgetId() async => currentBudgetId;

  @override
  Future<void> saveCurrentUserId(String userId) async {
    currentUserId = userId;
  }

  @override
  Future<void> saveCurrentBudgetId(String budgetId) async {
    currentBudgetId = budgetId;
  }

  @override
  Future<void> saveSession({
    required String userId,
    required String budgetId,
  }) async {
    if (failSaveSession) {
      throw StateError('preferences unavailable');
    }

    currentUserId = userId;
    currentBudgetId = budgetId;
  }
}

final class FakeIdGenerator implements IdGenerator {
  FakeIdGenerator(this._ids);

  final List<String> _ids;

  @override
  String nextId() {
    if (_ids.isEmpty) {
      throw StateError('No fake ids left');
    }

    return _ids.removeAt(0);
  }
}

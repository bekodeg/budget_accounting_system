import 'dart:async';

import 'package:budget_accounting_system/src/application/app_services.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/session_store.dart';
import 'package:budget_accounting_system/src/application/use_cases/apply_category_templates.dart';
import 'package:budget_accounting_system/src/application/use_cases/archive_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/archive_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_initial_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_account_balance.dart';
import 'package:budget_accounting_system/src/application/use_cases/rename_category.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/resolve_app_startup.dart';
import 'package:budget_accounting_system/src/application/use_cases/select_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_budget_accounts.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_budget_categories.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_user_budgets.dart';
import 'package:budget_accounting_system/src/domain/models/account_balance.dart';
import 'package:budget_accounting_system/src/domain/models/app_session.dart';
import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/models/category_template.dart';
import 'package:budget_accounting_system/src/domain/models/initial_budget_category.dart';
import 'package:budget_accounting_system/src/domain/repositories/account_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/budget_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/category_repository.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';

AppServices fakeAppServices({
  required FakeBudgetRepository repository,
  required FakeSessionStore sessionStore,
  FakeCategoryRepository? categoryRepository,
  FakeAccountRepository? accountRepository,
  FakeIdGenerator? idGenerator,
}) {
  final categories = categoryRepository ?? FakeCategoryRepository();
  final accounts = accountRepository ?? FakeAccountRepository();
  final ids = idGenerator ?? FakeIdGenerator([
    'user-1',
    'budget-1',
    'entity-1',
    'entity-2',
  ]);

  return AppServices(
    applyCategoryTemplates: ApplyCategoryTemplates(categories),
    archiveAccount: ArchiveAccount(accounts),
    archiveCategory: ArchiveCategory(categories),
    createAccount: CreateAccount(
      accountRepository: accounts,
      idGenerator: ids,
    ),
    createCategory: CreateCategory(
      categoryRepository: categories,
      idGenerator: ids,
    ),
    createInitialBudget: CreateInitialBudget(
      budgetRepository: repository,
      categoryRepository: categories,
      sessionStore: sessionStore,
      idGenerator: ids,
    ),
    getAccountBalance: GetAccountBalance(accounts),
    renameCategory: RenameCategory(categories),
    requireAccountInBudget: RequireAccountInBudget(accounts),
    resolveAppStartup: ResolveAppStartup(
      budgetRepository: repository,
      sessionStore: sessionStore,
    ),
    selectBudget: SelectBudget(
      budgetRepository: repository,
      sessionStore: sessionStore,
    ),
    updateAccount: UpdateAccount(accounts),
    watchBudgetAccounts: WatchBudgetAccounts(accounts),
    watchBudgetCategories: WatchBudgetCategories(categories),
    watchUserBudgets: WatchUserBudgets(repository),
  );
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
  String? createdBudgetId;
  String? createdBudgetName;
  Currency? createdCurrency;
  List<InitialBudgetCategory> createdInitialCategories = const [];

  @override
  Future<AppSession> createOwnedBudget({
    required String userId,
    required String userName,
    required String publicKey,
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
    return List<BudgetSummary>.unmodifiable(
      budgetsByUser[userId] ?? const [],
    );
  }

  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    return Stream.value(
      List<BudgetSummary>.unmodifiable(
        budgetsByUser[userId] ?? const [],
      ),
    );
  }
}

final class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository({
    List<CategoryTemplate>? templates,
    Map<String, List<BudgetCategory>>? categoriesByBudget,
  })  : templates = templates ?? const [],
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
    required String categoryId,
    required String name,
  }) async {
    for (final entry in categoriesByBudget.entries) {
      final index = entry.value.indexWhere(
        (category) => category.id == categoryId,
      );
      if (index >= 0) {
        entry.value[index] = entry.value[index].copyWith(name: name);
        _emit(entry.key);
        return;
      }
    }
  }

  @override
  Future<void> setCategoryArchived({
    required String categoryId,
    required bool isArchived,
  }) async {
    for (final entry in categoriesByBudget.entries) {
      final index = entry.value.indexWhere(
        (category) => category.id == categoryId,
      );
      if (index >= 0) {
        entry.value[index] = entry.value[index].copyWith(
          isArchived: isArchived,
        );
        _emit(entry.key);
        return;
      }
    }
  }
}

final class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    Map<String, List<BudgetAccount>>? accountsByBudget,
    Map<String, BigInt>? transactionDeltaByAccount,
    Set<String>? accountsWithTransactions,
  })  : accountsByBudget = accountsByBudget ?? {},
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
    final account = await findAccount(
      budgetId: budgetId,
      accountId: accountId,
    );
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
  }) async {
    final account = await findAccount(
      budgetId: budgetId,
      accountId: accountId,
    );
    if (account == null) return null;
    return AccountBalance(
      accountId: account.id,
      minorUnits: account.openingBalanceMinor +
          (transactionDeltaByAccount[account.id] ?? BigInt.zero),
      currency: account.currency,
    );
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

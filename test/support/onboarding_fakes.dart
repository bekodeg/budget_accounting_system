import 'package:budget_accounting_system/src/application/app_services.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/session_store.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_initial_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/resolve_app_startup.dart';
import 'package:budget_accounting_system/src/application/use_cases/select_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/watch_user_budgets.dart';
import 'package:budget_accounting_system/src/domain/models/app_session.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/repositories/budget_repository.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';

AppServices fakeAppServices({
  required FakeBudgetRepository repository,
  required FakeSessionStore sessionStore,
  FakeIdGenerator? idGenerator,
}) {
  final ids = idGenerator ?? FakeIdGenerator(['user-1', 'budget-1']);

  return AppServices(
    createInitialBudget: CreateInitialBudget(
      budgetRepository: repository,
      sessionStore: sessionStore,
      idGenerator: ids,
    ),
    resolveAppStartup: ResolveAppStartup(
      budgetRepository: repository,
      sessionStore: sessionStore,
    ),
    selectBudget: SelectBudget(
      budgetRepository: repository,
      sessionStore: sessionStore,
    ),
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

  @override
  Future<AppSession> createOwnedBudget({
    required String userId,
    required String userName,
    required String publicKey,
    required String budgetId,
    required String budgetName,
    required Currency baseCurrency,
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

import '../../domain/models/app_session.dart';
import '../../domain/models/budget_summary.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/initial_budget_category.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../dal/user_budget_dao.dart';
import '../database/app_database.dart';

final class DriftBudgetRepository implements BudgetRepository {
  const DriftBudgetRepository(this._dao);

  final UserBudgetDao _dao;

  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    return _dao.watchBudgetsForUser(userId).map(_toSummaries);
  }

  @override
  Future<List<BudgetSummary>> getBudgetsForUser(String userId) async {
    final budgets = await _dao.getBudgetsForUser(userId);
    return _toSummaries(budgets);
  }

  @override
  Future<String?> findFirstUserIdWithBudget() {
    return _dao.findFirstUserIdWithBudget();
  }

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
    await _dao.createOwnedBudget(
      user: UsersCompanion.insert(
        id: userId,
        name: userName,
        publicKey: publicKey,
      ),
      budget: BudgetsCompanion.insert(
        id: budgetId,
        name: budgetName,
        baseCurrency: baseCurrency.code,
        createdBy: userId,
      ),
      ownerMembership: BudgetMembersCompanion.insert(
        budgetId: budgetId,
        userId: userId,
        role: 'OWNER',
      ),
      initialCategories: initialCategories
          .map(
            (category) => CategoriesCompanion.insert(
              id: category.id,
              budgetId: budgetId,
              name: category.name,
              kind: _categoryKindToStorage(category.kind),
            ),
          )
          .toList(growable: false),
    );

    return AppSession(userId: userId, budgetId: budgetId);
  }

  List<BudgetSummary> _toSummaries(List<Budget> budgets) {
    return budgets
        .map(
          (budget) => BudgetSummary(
            id: budget.id,
            name: budget.name,
            baseCurrency: budget.baseCurrency,
          ),
        )
        .toList(growable: false);
  }
}

String _categoryKindToStorage(CategoryKind kind) {
  return switch (kind) {
    CategoryKind.income => 'INCOME',
    CategoryKind.expense => 'EXPENSE',
    CategoryKind.both => 'BOTH',
  };
}

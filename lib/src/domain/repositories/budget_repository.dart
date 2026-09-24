import '../models/app_session.dart';
import '../models/budget_summary.dart';
import '../models/initial_budget_category.dart';
import '../value_objects/currency.dart';

abstract interface class BudgetRepository {
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId);

  Future<List<BudgetSummary>> getBudgetsForUser(String userId);

  Future<String?> findFirstUserIdWithBudget();

  Future<AppSession> createOwnedBudget({
    required String userId,
    required String userName,
    required String publicKey,
    required String budgetId,
    required String budgetName,
    required Currency baseCurrency,
    List<InitialBudgetCategory> initialCategories = const [],
  });
}

import 'package:budget_accounting_system/src/application/use_cases/watch_user_budgets.dart';
import 'package:budget_accounting_system/src/domain/models/app_session.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/models/initial_budget_category.dart';
import 'package:budget_accounting_system/src/domain/repositories/budget_repository.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forwards user id to repository and exposes domain budgets', () async {
    final repository = _FakeBudgetRepository(
      budgets: const [
        BudgetSummary(id: 'budget-1', name: 'Дом', baseCurrency: 'EUR'),
      ],
    );
    final useCase = WatchUserBudgets(repository);

    final result = await useCase('user-1').first;

    expect(repository.lastUserId, 'user-1');
    expect(result, const [
      BudgetSummary(id: 'budget-1', name: 'Дом', baseCurrency: 'EUR'),
    ]);
  });
}

final class _FakeBudgetRepository implements BudgetRepository {
  _FakeBudgetRepository({required this.budgets});

  final List<BudgetSummary> budgets;
  String? lastUserId;

  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    lastUserId = userId;
    return Stream.value(budgets);
  }

  @override
  Future<List<BudgetSummary>> getBudgetsForUser(String userId) async {
    lastUserId = userId;
    return budgets;
  }

  @override
  Future<String?> findFirstUserIdWithBudget() async {
    return budgets.isEmpty ? null : 'user-1';
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
  }) {
    throw UnimplementedError('Not needed by WatchUserBudgets tests.');
  }
}

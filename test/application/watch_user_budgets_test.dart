import 'package:budget_accounting_system/src/application/use_cases/watch_user_budgets.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/repositories/budget_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forwards user id to repository and exposes domain budgets', () async {
    final repository = _FakeBudgetRepository(
      budgets: const [
        BudgetSummary(
          id: 'budget-1',
          name: 'Дом',
          baseCurrency: 'EUR',
        ),
      ],
    );
    final useCase = WatchUserBudgets(repository);

    final result = await useCase('user-1').first;

    expect(repository.lastUserId, 'user-1');
    expect(
      result,
      const [
        BudgetSummary(
          id: 'budget-1',
          name: 'Дом',
          baseCurrency: 'EUR',
        ),
      ],
    );
  });
}

final class _FakeBudgetRepository implements BudgetRepository {
  _FakeBudgetRepository({
    required this.budgets,
  });

  final List<BudgetSummary> budgets;
  String? lastUserId;

  @override
  Stream<List<BudgetSummary>> watchBudgetsForUser(String userId) {
    lastUserId = userId;
    return Stream.value(budgets);
  }
}

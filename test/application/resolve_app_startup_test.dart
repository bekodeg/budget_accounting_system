import 'package:budget_accounting_system/src/application/use_cases/resolve_app_startup.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  test('shows onboarding when no local identity exists', () async {
    final useCase = ResolveAppStartup(
      budgetRepository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
    );

    final state = await useCase();

    expect(state.needsOnboarding, isTrue);
  });

  test('reconstructs session from Drift when preferences are empty', () async {
    final repository = FakeBudgetRepository(
      firstUserId: 'user-1',
      budgetsByUser: {
        'user-1': const [
          BudgetSummary(id: 'budget-1', name: 'Family', baseCurrency: 'EUR'),
        ],
      },
    );
    final sessionStore = FakeSessionStore();
    final useCase = ResolveAppStartup(
      budgetRepository: repository,
      sessionStore: sessionStore,
    );

    final state = await useCase();

    expect(state.userId, 'user-1');
    expect(state.selectedBudgetId, 'budget-1');
    expect(sessionStore.currentUserId, 'user-1');
    expect(sessionStore.currentBudgetId, 'budget-1');
  });

  test(
    'asks user to select when several budgets have no last selection',
    () async {
      final repository = FakeBudgetRepository(
        firstUserId: 'user-1',
        budgetsByUser: {
          'user-1': const [
            BudgetSummary(id: 'budget-1', name: 'Home', baseCurrency: 'EUR'),
            BudgetSummary(id: 'budget-2', name: 'Trip', baseCurrency: 'USD'),
          ],
        },
      );
      final useCase = ResolveAppStartup(
        budgetRepository: repository,
        sessionStore: FakeSessionStore(currentUserId: 'user-1'),
      );

      final state = await useCase();

      expect(state.needsBudgetSelection, isTrue);
      expect(state.selectedBudgetId, isNull);
    },
  );

  test('falls back to Drift when stored user id is stale', () async {
    final repository = FakeBudgetRepository(
      firstUserId: 'user-1',
      budgetsByUser: {
        'user-1': const [
          BudgetSummary(id: 'budget-1', name: 'Home', baseCurrency: 'EUR'),
        ],
      },
    );
    final sessionStore = FakeSessionStore(
      currentUserId: 'missing-user',
      currentBudgetId: 'missing-budget',
    );
    final useCase = ResolveAppStartup(
      budgetRepository: repository,
      sessionStore: sessionStore,
    );

    final state = await useCase();

    expect(state.userId, 'user-1');
    expect(state.selectedBudgetId, 'budget-1');
    expect(sessionStore.currentUserId, 'user-1');
    expect(sessionStore.currentBudgetId, 'budget-1');
  });

  test('restores valid last selected budget', () async {
    final repository = FakeBudgetRepository(
      firstUserId: 'user-1',
      budgetsByUser: {
        'user-1': const [
          BudgetSummary(id: 'budget-1', name: 'Home', baseCurrency: 'EUR'),
          BudgetSummary(id: 'budget-2', name: 'Trip', baseCurrency: 'USD'),
        ],
      },
    );
    final useCase = ResolveAppStartup(
      budgetRepository: repository,
      sessionStore: FakeSessionStore(
        currentUserId: 'user-1',
        currentBudgetId: 'budget-2',
      ),
    );

    final state = await useCase();

    expect(state.selectedBudgetId, 'budget-2');
    expect(state.needsBudgetSelection, isFalse);
  });
}

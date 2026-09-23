import 'package:budget_accounting_system/src/application/errors/onboarding_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/select_budget.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  test('persists accessible budget selection', () async {
    final repository = FakeBudgetRepository(
      budgetsByUser: {
        'user-1': const [
          BudgetSummary(id: 'budget-1', name: 'Home', baseCurrency: 'EUR'),
        ],
      },
    );
    final sessionStore = FakeSessionStore();
    final useCase = SelectBudget(
      budgetRepository: repository,
      sessionStore: sessionStore,
    );

    final session = await useCase(
      userId: 'user-1',
      budgetId: 'budget-1',
    );

    expect(session.budgetId, 'budget-1');
    expect(sessionStore.currentUserId, 'user-1');
    expect(sessionStore.currentBudgetId, 'budget-1');
  });

  test('rejects budget outside current user memberships', () async {
    final useCase = SelectBudget(
      budgetRepository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
    );

    await expectLater(
      useCase(userId: 'user-1', budgetId: 'budget-404'),
      throwsA(
        isA<OnboardingError>().having(
          (error) => error.code,
          'code',
          OnboardingErrorCode.inaccessibleBudget,
        ),
      ),
    );
  });
}

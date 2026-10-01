import 'package:budget_accounting_system/src/application/use_cases/ensure_local_identity.dart';
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

  test('migrates legacy identity before restoring the session', () async {
    final budgetRepository = FakeBudgetRepository(
      firstUserId: 'user-1',
      budgetsByUser: {
        'user-1': const [
          BudgetSummary(id: 'budget-1', name: 'Home', baseCurrency: 'EUR'),
        ],
      },
    );
    final identityRepository = FakeIdentityRepository(
      publicKeysByUser: {'user-1': 'local-unverified:user-1'},
    );
    final keyStore = FakeIdentityKeyStore();
    final ensureIdentity = EnsureLocalIdentity(
      identityRepository: identityRepository,
      keyStore: keyStore,
      keyPairGenerator: FakeIdentityKeyPairGenerator(),
      idGenerator: FakeIdGenerator(['device-1']),
    );
    final useCase = ResolveAppStartup(
      budgetRepository: budgetRepository,
      sessionStore: FakeSessionStore(),
      ensureLocalIdentity: ensureIdentity,
    );

    final state = await useCase();

    expect(state.selectedBudgetId, 'budget-1');
    expect(
      identityRepository.publicKeysByUser['user-1'],
      'ed25519:public-test-key',
    );
    expect(identityRepository.devicesById['device-1']?.userId, 'user-1');
    expect(keyStore.privateKeyByDevice['device-1'], 'private-test-key');
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

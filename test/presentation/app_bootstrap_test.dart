import 'package:budget_accounting_system/src/app.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/models/category_template.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('first launch creates local user and opens budget', (
    tester,
  ) async {
    final repository = FakeBudgetRepository();
    final sessionStore = FakeSessionStore();
    final services = fakeAppServices(
      repository: repository,
      sessionStore: sessionStore,
      idGenerator: FakeIdGenerator(['user-1', 'budget-1', 'device-1']),
    );

    await tester.pumpWidget(BudgetAccountingApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Первый запуск'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-user-name')),
      'Alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-budget-name')),
      'Дом',
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-currency')),
      'EUR',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transaction-crud')), findsOneWidget);
    expect(find.text('Дом'), findsOneWidget);
    expect(sessionStore.currentUserId, 'user-1');
    expect(sessionStore.currentBudgetId, 'budget-1');
  });


  testWidgets('fresh device joins existing budget from invite file', (
    tester,
  ) async {
    final ownerServices = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(currentUserId: 'owner-1'),
      idGenerator: FakeIdGenerator(['owner-device', 'invite-1']),
    );
    final invite = await ownerServices.createBudgetInvite(
      budgetId: 'budget-1',
      role: MemberRole.editor,
    );

    final repository = FakeBudgetRepository();
    final sessionStore = FakeSessionStore();
    final inviteFiles = FakeInviteFileGateway()
      ..pickedPayload = invite.rawPayload;
    final identityKeys = FakeIdentityKeyStore();
    final services = fakeAppServices(
      repository: repository,
      sessionStore: sessionStore,
      inviteFileGateway: inviteFiles,
      identityKeyStore: identityKeys,
      idGenerator: FakeIdGenerator(['user-2', 'device-2']),
    );

    await tester.pumpWidget(BudgetAccountingApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Первый запуск'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-scan-invite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-open-invite-file')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-user-name')),
      'Bob',
    );
    await tester.tap(
      find.byKey(const ValueKey('onboarding-open-invite-file')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Присоединиться к бюджету?'), findsOneWidget);
    expect(find.text('Бюджет: Test budget'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-confirm-invite')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test budget'), findsOneWidget);
    expect(sessionStore.currentUserId, 'user-2');
    expect(sessionStore.currentBudgetId, 'budget-1');
    expect(identityKeys.deviceByUser['user-2'], 'device-2');
  });

  testWidgets('can opt out from standard categories on first launch', (
    tester,
  ) async {
    final repository = FakeBudgetRepository();
    final categoryRepository = FakeCategoryRepository(
      templates: const [
        CategoryTemplate(
          code: 'expense.food',
          name: 'Продукты',
          kind: CategoryKind.expense,
          sortOrder: 10,
        ),
      ],
    );
    final services = fakeAppServices(
      repository: repository,
      categoryRepository: categoryRepository,
      sessionStore: FakeSessionStore(),
      idGenerator: FakeIdGenerator(['user-1', 'budget-1', 'device-1']),
    );

    await tester.pumpWidget(BudgetAccountingApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('onboarding-default-categories')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-user-name')),
      'Alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-budget-name')),
      'Дом',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-submit')));
    await tester.pumpAndSettle();

    expect(repository.createdInitialCategories, isEmpty);
  });

  testWidgets('database error keeps entered onboarding values', (tester) async {
    final repository = FakeBudgetRepository(
      createError: StateError('database unavailable'),
    );
    final services = fakeAppServices(
      repository: repository,
      sessionStore: FakeSessionStore(),
      idGenerator: FakeIdGenerator(['user-1', 'budget-1', 'device-1']),
    );

    await tester.pumpWidget(BudgetAccountingApp(services: services));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-user-name')),
      'Alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-budget-name')),
      'Дом',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onboarding-error')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Дом'), findsOneWidget);
  });

  testWidgets(
    'shows budget picker when several budgets have no last selection',
    (tester) async {
      final repository = FakeBudgetRepository(
        firstUserId: 'user-1',
        budgetsByUser: {
          'user-1': const [
            BudgetSummary(id: 'budget-1', name: 'Дом', baseCurrency: 'EUR'),
            BudgetSummary(id: 'budget-2', name: 'Поездка', baseCurrency: 'USD'),
          ],
        },
      );
      final sessionStore = FakeSessionStore(currentUserId: 'user-1');
      final services = fakeAppServices(
        repository: repository,
        sessionStore: sessionStore,
      );

      await tester.pumpWidget(BudgetAccountingApp(services: services));
      await tester.pumpAndSettle();

      expect(find.text('Выберите бюджет'), findsOneWidget);
      expect(find.text('Дом'), findsOneWidget);
      expect(find.text('Поездка'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('budget-budget-2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('transaction-crud')), findsOneWidget);
      expect(find.text('Поездка'), findsOneWidget);
      expect(sessionStore.currentBudgetId, 'budget-2');
    },
  );

  testWidgets('allows switching budget from application shell', (tester) async {
    final repository = FakeBudgetRepository(
      firstUserId: 'user-1',
      budgetsByUser: {
        'user-1': const [
          BudgetSummary(id: 'budget-1', name: 'Дом', baseCurrency: 'EUR'),
          BudgetSummary(id: 'budget-2', name: 'Поездка', baseCurrency: 'USD'),
        ],
      },
    );
    final sessionStore = FakeSessionStore(
      currentUserId: 'user-1',
      currentBudgetId: 'budget-1',
    );
    final services = fakeAppServices(
      repository: repository,
      sessionStore: sessionStore,
    );

    await tester.pumpWidget(BudgetAccountingApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Дом'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('choose-budget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget-budget-2')));
    await tester.pumpAndSettle();

    expect(find.text('Поездка'), findsOneWidget);
    expect(sessionStore.currentBudgetId, 'budget-2');
  });
}

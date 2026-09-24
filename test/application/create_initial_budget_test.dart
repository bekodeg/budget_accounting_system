import 'package:budget_accounting_system/src/application/errors/onboarding_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_initial_budget.dart';
import 'package:budget_accounting_system/src/domain/models/category_template.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  test('creates owner budget and persists current session', () async {
    final repository = FakeBudgetRepository();
    final categoryRepository = FakeCategoryRepository();
    final sessionStore = FakeSessionStore();
    final useCase = CreateInitialBudget(
      budgetRepository: repository,
      categoryRepository: categoryRepository,
      sessionStore: sessionStore,
      idGenerator: FakeIdGenerator(['user-1', 'budget-1']),
    );

    final session = await useCase(
      userName: '  Alice  ',
      budgetName: '  Family  ',
      baseCurrency: Currency('eur'),
    );

    expect(session.userId, 'user-1');
    expect(session.budgetId, 'budget-1');
    expect(repository.createdUserName, 'Alice');
    expect(repository.createdBudgetName, 'Family');
    expect(repository.createdCurrency, Currency('EUR'));
    expect(repository.createdPublicKey, 'local-unverified:user-1');
    expect(sessionStore.currentUserId, 'user-1');
    expect(sessionStore.currentBudgetId, 'budget-1');
  });

  test('includes default templates in the atomic budget creation', () async {
    final repository = FakeBudgetRepository();
    final categoryRepository = FakeCategoryRepository(
      templates: const [
        CategoryTemplate(
          code: 'expense.food',
          name: 'Продукты',
          kind: CategoryKind.expense,
          sortOrder: 10,
        ),
        CategoryTemplate(
          code: 'income.salary',
          name: 'Зарплата',
          kind: CategoryKind.income,
          sortOrder: 10,
        ),
      ],
    );
    final useCase = CreateInitialBudget(
      budgetRepository: repository,
      categoryRepository: categoryRepository,
      sessionStore: FakeSessionStore(),
      idGenerator: FakeIdGenerator(['user-1', 'budget-1']),
    );

    await useCase(
      userName: 'Alice',
      budgetName: 'Family',
      baseCurrency: Currency('EUR'),
    );

    expect(repository.createdInitialCategories, hasLength(2));
    expect(
      repository.createdInitialCategories.map((category) => category.id),
      containsAll([
        'budget-1:template:expense.food',
        'budget-1:template:income.salary',
      ]),
    );
  });

  test('can create first budget without standard categories', () async {
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
    final useCase = CreateInitialBudget(
      budgetRepository: repository,
      categoryRepository: categoryRepository,
      sessionStore: FakeSessionStore(),
      idGenerator: FakeIdGenerator(['user-1', 'budget-1']),
    );

    await useCase(
      userName: 'Alice',
      budgetName: 'Family',
      baseCurrency: Currency('EUR'),
      applyDefaultCategories: false,
    );

    expect(repository.createdInitialCategories, isEmpty);
  });

  test('rejects blank names before touching storage', () async {
    final repository = FakeBudgetRepository();
    final sessionStore = FakeSessionStore();
    final useCase = CreateInitialBudget(
      budgetRepository: repository,
      categoryRepository: FakeCategoryRepository(),
      sessionStore: sessionStore,
      idGenerator: FakeIdGenerator(['user-1', 'budget-1']),
    );

    await expectLater(
      useCase(
        userName: '   ',
        budgetName: 'Family',
        baseCurrency: Currency('EUR'),
      ),
      throwsA(
        isA<OnboardingError>().having(
          (error) => error.code,
          'code',
          OnboardingErrorCode.emptyUserName,
        ),
      ),
    );

    expect(repository.createdUserId, isNull);
    expect(sessionStore.currentUserId, isNull);
  });

  test(
    'keeps created budget usable if preferences cannot be written',
    () async {
      final repository = FakeBudgetRepository();
      final sessionStore = FakeSessionStore(failSaveSession: true);
      final useCase = CreateInitialBudget(
        budgetRepository: repository,
        categoryRepository: FakeCategoryRepository(),
        sessionStore: sessionStore,
        idGenerator: FakeIdGenerator(['user-1', 'budget-1']),
      );

      final session = await useCase(
        userName: 'Alice',
        budgetName: 'Family',
        baseCurrency: Currency('EUR'),
      );

      expect(session.userId, 'user-1');
      expect(repository.firstUserId, 'user-1');
      expect(sessionStore.currentUserId, isNull);
    },
  );
}

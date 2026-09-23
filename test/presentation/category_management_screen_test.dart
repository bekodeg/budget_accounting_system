import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/presentation/screens/category_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('creates category from management screen', (tester) async {
    final categoryRepository = FakeCategoryRepository();
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      categoryRepository: categoryRepository,
      sessionStore: FakeSessionStore(),
      idGenerator: FakeIdGenerator(['category-1']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryManagementScreen(
            services: services,
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-name-input')),
      'Продукты',
    );
    await tester.tap(find.byKey(const ValueKey('save-category')));
    await tester.pumpAndSettle();

    expect(find.text('Продукты'), findsOneWidget);
    final categories = categoryRepository.snapshot(
      'budget-1',
      includeArchived: false,
    );
    expect(categories.single.kind, CategoryKind.expense);
  });

  testWidgets('renames and archives existing category', (tester) async {
    final categoryRepository = FakeCategoryRepository(
      categoriesByBudget: {
        'budget-1': [
          const BudgetCategory(
            id: 'category-1',
            budgetId: 'budget-1',
            name: 'Еда',
            kind: CategoryKind.expense,
            isArchived: false,
          ),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      categoryRepository: categoryRepository,
      sessionStore: FakeSessionStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryManagementScreen(
            services: services,
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('category-menu-category-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rename-category-input')),
      'Продукты',
    );
    await tester.tap(find.byKey(const ValueKey('rename-category-save')));
    await tester.pumpAndSettle();

    expect(find.text('Продукты'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('category-menu-category-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архивировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Архивировать'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('archived-category-category-1')),
      findsOneWidget,
    );
    expect(
      categoryRepository.snapshot(
        'budget-1',
        includeArchived: false,
      ),
      isEmpty,
    );
  });
}

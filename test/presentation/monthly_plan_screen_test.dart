import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/presentation/screens/monthly_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('edits active expense plan and updates total reactively', (
    tester,
  ) async {
    final categories = FakeCategoryRepository(
      categoriesByBudget: {
        'budget-1': const [
          BudgetCategory(
            id: 'food',
            budgetId: 'budget-1',
            name: 'Еда',
            kind: CategoryKind.expense,
            isArchived: false,
          ),
          BudgetCategory(
            id: 'salary',
            budgetId: 'budget-1',
            name: 'Зарплата',
            kind: CategoryKind.income,
            isArchived: false,
          ),
        ],
      },
    );
    final plans = FakePlanRepository();
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      categoryRepository: categories,
      planRepository: plans,
      idGenerator: FakeIdGenerator(['plan-1']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyPlanScreen(services: services, budgetId: 'budget-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Еда'), findsOneWidget);
    expect(find.text('Зарплата'), findsNothing);
    expect(find.byKey(const ValueKey('plan-total')), findsOneWidget);
    expect(find.text('0.00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('plan-category-food')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-amount-input')),
      '125.50',
    );
    await tester.tap(find.byKey(const ValueKey('save-plan-amount')));
    await tester.pumpAndSettle();

    expect(find.text('125.50'), findsWidgets);
    expect(
      plans.snapshot('budget-1', DateTime.now()).single.plannedAmountMinor,
      BigInt.from(12550),
    );
  });
}

import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/presentation/screens/transaction_crud_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('creates edits and soft deletes expense', (tester) async {
    final accountRepository = FakeAccountRepository(
      accountsByBudget: {
        'budget-1': [
          BudgetAccount(
            id: 'account-1',
            budgetId: 'budget-1',
            name: 'Карта',
            openingBalanceMinor: BigInt.zero,
            currency: Currency('EUR'),
            isArchived: false,
          ),
        ],
      },
    );
    final categoryRepository = FakeCategoryRepository(
      categoriesByBudget: {
        'budget-1': const [
          BudgetCategory(
            id: 'category-1',
            budgetId: 'budget-1',
            name: 'Продукты',
            kind: CategoryKind.expense,
            isArchived: false,
          ),
        ],
      },
    );
    final transactionRepository = FakeTransactionRepository();
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      accountRepository: accountRepository,
      categoryRepository: categoryRepository,
      transactionRepository: transactionRepository,
      idGenerator: FakeIdGenerator(['transaction-1']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionCrudScreen(
            services: services,
            budgetId: 'budget-1',
            userId: 'user-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-transaction')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('transaction-amount')),
      '12.50',
    );
    await tester.enterText(
      find.byKey(const ValueKey('transaction-description')),
      'Кофе',
    );
    await tester.tap(find.byKey(const ValueKey('save-transaction')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('transaction-transaction-1')),
      findsOneWidget,
    );
    expect(find.text('-12.50 EUR'), findsOneWidget);
    expect(find.textContaining('Кофе'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transaction-transaction-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('transaction-amount')),
      '20.00',
    );
    await tester.tap(find.byKey(const ValueKey('save-transaction')));
    await tester.pumpAndSettle();

    expect(find.text('-20.00 EUR'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('transaction-menu-transaction-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-transaction')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('transaction-transaction-1')),
      findsNothing,
    );
    expect(transactionRepository.snapshot('budget-1'), isEmpty);
  });
}

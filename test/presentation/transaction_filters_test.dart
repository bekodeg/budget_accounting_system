import 'package:budget_accounting_system/src/domain/models/budget_transaction_entry.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/domain/value_objects/money.dart';
import 'package:budget_accounting_system/src/presentation/screens/transaction_crud_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  BudgetTransactionEntry transaction({
    required String id,
    required String authorId,
    required TransactionType type,
  }) {
    final now = DateTime(2026, 9, 24, 10);
    return BudgetTransactionEntry(
      id: id,
      budgetId: 'budget-1',
      occurredAt: now,
      amount: Money.positive(
        minorUnits: BigInt.from(1000),
        currency: Currency('EUR'),
      ),
      type: type,
      authorId: authorId,
      accountId: 'account-1',
      destinationAccountId: null,
      categoryId: type == TransactionType.transfer ? null : 'category-1',
      description: id,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('filters journal to current user reactively', (tester) async {
    final transactionRepository = FakeTransactionRepository(
      transactionsByBudget: {
        'budget-1': [
          transaction(
            id: 'mine',
            authorId: 'user-1',
            type: TransactionType.expense,
          ),
          transaction(
            id: 'other',
            authorId: 'user-2',
            type: TransactionType.expense,
          ),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      transactionRepository: transactionRepository,
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

    expect(find.byKey(const ValueKey('transaction-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-other')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transaction-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-only-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transaction-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-other')), findsNothing);
    expect(find.text('Фильтры (1)'), findsOneWidget);

    await transactionRepository.createTransaction(
      transaction(
        id: 'mine-new',
        authorId: 'user-1',
        type: TransactionType.income,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transaction-mine-new')), findsOneWidget);
  });

  testWidgets('reset restores all transactions', (tester) async {
    final transactionRepository = FakeTransactionRepository(
      transactionsByBudget: {
        'budget-1': [
          transaction(
            id: 'mine',
            authorId: 'user-1',
            type: TransactionType.expense,
          ),
          transaction(
            id: 'other',
            authorId: 'user-2',
            type: TransactionType.expense,
          ),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      transactionRepository: transactionRepository,
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

    await tester.tap(find.byKey(const ValueKey('transaction-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-only-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-filters')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('transaction-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transaction-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-other')), findsOneWidget);
  });
}

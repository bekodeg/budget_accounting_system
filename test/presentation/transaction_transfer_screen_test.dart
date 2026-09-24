import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/presentation/screens/transaction_crud_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('creates transfer between two accounts', (tester) async {
    final accountRepository = FakeAccountRepository(
      accountsByBudget: {
        'budget-1': [
          BudgetAccount(
            id: 'source',
            budgetId: 'budget-1',
            name: 'Карта',
            openingBalanceMinor: BigInt.zero,
            currency: Currency('EUR'),
            isArchived: false,
          ),
          BudgetAccount(
            id: 'destination',
            budgetId: 'budget-1',
            name: 'Наличные',
            openingBalanceMinor: BigInt.zero,
            currency: Currency('EUR'),
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
      transactionRepository: transactionRepository,
      idGenerator: FakeIdGenerator(['transfer-1']),
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
    await tester.tap(find.text('Перевод'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('transaction-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Карта · EUR').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('transaction-amount')),
      '50.00',
    );
    await tester.tap(find.byKey(const ValueKey('save-transaction')));
    await tester.pumpAndSettle();

    final transfer = transactionRepository.snapshot('budget-1').single;
    expect(transfer.accountId, 'source');
    expect(transfer.destinationAccountId, 'destination');
    expect(find.text('↔ 50.00 EUR'), findsOneWidget);
  });
}

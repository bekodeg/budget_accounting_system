import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/presentation/screens/account_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('creates account with opening balance', (tester) async {
    final accountRepository = FakeAccountRepository();
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      accountRepository: accountRepository,
      sessionStore: FakeSessionStore(),
      idGenerator: FakeIdGenerator(['account-1']),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountManagementScreen(
            services: services,
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-name-input')),
      'Карта',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-opening-balance-input')),
      '1200.50',
    );
    await tester.tap(find.byKey(const ValueKey('save-account')));
    await tester.pumpAndSettle();

    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('Остаток: 1200.50 EUR'), findsOneWidget);
    expect(
      accountRepository
          .snapshot('budget-1', includeArchived: false)
          .single
          .openingBalanceMinor,
      BigInt.from(120050),
    );
  });

  testWidgets('edits and archives account without deleting it', (tester) async {
    final accountRepository = FakeAccountRepository(
      accountsByBudget: {
        'budget-1': [
          BudgetAccount(
            id: 'account-1',
            budgetId: 'budget-1',
            name: 'Карта',
            openingBalanceMinor: BigInt.from(10000),
            currency: Currency('EUR'),
            isArchived: false,
          ),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      accountRepository: accountRepository,
      sessionStore: FakeSessionStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountManagementScreen(
            services: services,
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-menu-account-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-name-input')),
      'Основная карта',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-opening-balance-input')),
      '250.00',
    );
    await tester.tap(find.byKey(const ValueKey('save-account')));
    await tester.pumpAndSettle();

    expect(find.text('Основная карта'), findsOneWidget);
    expect(find.text('Остаток: 250.00 EUR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-menu-account-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Архивировать'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-archive-account')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('archived-account-account-1')),
      findsOneWidget,
    );
    expect(
      accountRepository.snapshot('budget-1', includeArchived: false),
      isEmpty,
    );
    expect(
      accountRepository.snapshot('budget-1', includeArchived: true),
      hasLength(1),
    );
  });
}

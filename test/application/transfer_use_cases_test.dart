import 'package:budget_accounting_system/src/application/use_cases/create_transfer.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
import 'package:budget_accounting_system/src/domain/errors/domain_validation_error.dart';
import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  FakeAccountRepository accounts({
    Currency? destinationCurrency,
  }) {
    return FakeAccountRepository(
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
            currency: destinationCurrency ?? Currency('EUR'),
            isArchived: false,
          ),
        ],
      },
    );
  }

  test('creates transfer without category', () async {
    final accountRepository = accounts();
    final transactionRepository = FakeTransactionRepository();
    final useCase = CreateTransfer(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      idGenerator: FakeIdGenerator(['transfer-1']),
    );

    final transfer = await useCase(
      budgetId: 'budget-1',
      authorId: 'user-1',
      occurredAt: DateTime(2026, 9, 24),
      amountMinor: BigInt.from(5000),
      sourceAccountId: 'source',
      destinationAccountId: 'destination',
    );

    expect(transfer.type, TransactionType.transfer);
    expect(transfer.categoryId, isNull);
    expect(transfer.accountId, 'source');
    expect(transfer.destinationAccountId, 'destination');
  });

  test('rejects transfer to the same account', () async {
    final accountRepository = accounts();
    final useCase = CreateTransfer(
      transactionRepository: FakeTransactionRepository(),
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      idGenerator: FakeIdGenerator(['transfer-1']),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        authorId: 'user-1',
        occurredAt: DateTime(2026, 9, 24),
        amountMinor: BigInt.from(5000),
        sourceAccountId: 'source',
        destinationAccountId: 'source',
      ),
      throwsA(
        isA<DomainValidationError>().having(
          (error) => error.code,
          'code',
          DomainValidationCode.sameTransferAccount,
        ),
      ),
    );
  });

  test('rejects cross-currency transfer', () async {
    final accountRepository = accounts(
      destinationCurrency: Currency('USD'),
    );
    final useCase = CreateTransfer(
      transactionRepository: FakeTransactionRepository(),
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      idGenerator: FakeIdGenerator(['transfer-1']),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        authorId: 'user-1',
        occurredAt: DateTime(2026, 9, 24),
        amountMinor: BigInt.from(5000),
        sourceAccountId: 'source',
        destinationAccountId: 'destination',
      ),
      throwsA(
        isA<DomainValidationError>().having(
          (error) => error.code,
          'code',
          DomainValidationCode.currencyMismatch,
        ),
      ),
    );
  });
}

import 'package:budget_accounting_system/src/application/errors/account_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/archive_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_account.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_account_balance.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_account.dart';
import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  final eur = Currency('EUR');

  test('creates account with signed opening balance in minor units', () async {
    final repository = FakeAccountRepository();
    final useCase = CreateAccount(
      accountRepository: repository,
      idGenerator: FakeIdGenerator(['account-1']),
    );

    final account = await useCase(
      budgetId: 'budget-1',
      name: '  Карта  ',
      currency: eur,
      openingBalanceMinor: BigInt.from(-1250),
    );

    expect(account.id, 'account-1');
    expect(account.name, 'Карта');
    expect(account.openingBalanceMinor, BigInt.from(-1250));
    expect(repository.snapshot('budget-1', includeArchived: false), [account]);
  });

  test('rejects empty account name', () async {
    final useCase = CreateAccount(
      accountRepository: FakeAccountRepository(),
      idGenerator: FakeIdGenerator(['account-1']),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        name: '  ',
        currency: eur,
        openingBalanceMinor: BigInt.zero,
      ),
      throwsA(
        isA<AccountError>().having(
          (error) => error.code,
          'code',
          AccountErrorCode.emptyName,
        ),
      ),
    );
  });

  test('does not allow editing account through another budget', () async {
    final repository = FakeAccountRepository(
      accountsByBudget: {
        'budget-2': [
          BudgetAccount(
            id: 'account-2',
            budgetId: 'budget-2',
            name: 'Чужая карта',
            openingBalanceMinor: BigInt.zero,
            currency: eur,
            isArchived: false,
          ),
        ],
      },
    );
    final useCase = UpdateAccount(repository);

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        accountId: 'account-2',
        name: 'Попытка',
        currency: eur,
        openingBalanceMinor: BigInt.zero,
      ),
      throwsA(
        isA<AccountError>().having(
          (error) => error.code,
          'code',
          AccountErrorCode.accountNotFound,
        ),
      ),
    );
  });

  test('locks currency after account has transactions', () async {
    final repository = FakeAccountRepository(
      accountsByBudget: {
        'budget-1': [
          BudgetAccount(
            id: 'account-1',
            budgetId: 'budget-1',
            name: 'Карта',
            openingBalanceMinor: BigInt.zero,
            currency: eur,
            isArchived: false,
          ),
        ],
      },
      accountsWithTransactions: {'account-1'},
    );
    final useCase = UpdateAccount(repository);

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        accountId: 'account-1',
        name: 'Карта',
        currency: Currency('USD'),
        openingBalanceMinor: BigInt.zero,
      ),
      throwsA(
        isA<AccountError>().having(
          (error) => error.code,
          'code',
          AccountErrorCode.currencyLockedByTransactions,
        ),
      ),
    );
  });

  test('ownership guard rejects archived and foreign accounts', () async {
    final repository = FakeAccountRepository(
      accountsByBudget: {
        'budget-1': [
          BudgetAccount(
            id: 'archived',
            budgetId: 'budget-1',
            name: 'Старый счет',
            openingBalanceMinor: BigInt.zero,
            currency: eur,
            isArchived: true,
          ),
        ],
        'budget-2': [
          BudgetAccount(
            id: 'foreign',
            budgetId: 'budget-2',
            name: 'Чужой счет',
            openingBalanceMinor: BigInt.zero,
            currency: eur,
            isArchived: false,
          ),
        ],
      },
    );
    final guard = RequireAccountInBudget(repository);

    await expectLater(
      guard(budgetId: 'budget-1', accountId: 'foreign'),
      throwsA(isA<AccountError>()),
    );
    await expectLater(
      guard(budgetId: 'budget-1', accountId: 'archived'),
      throwsA(isA<AccountError>()),
    );
  });

  test(
    'archive keeps account in full history and balance remains readable',
    () async {
      final account = BudgetAccount(
        id: 'account-1',
        budgetId: 'budget-1',
        name: 'Карта',
        openingBalanceMinor: BigInt.from(10000),
        currency: eur,
        isArchived: false,
      );
      final repository = FakeAccountRepository(
        accountsByBudget: {
          'budget-1': [account],
        },
        transactionDeltaByAccount: {'account-1': BigInt.from(2500)},
      );
      final archive = ArchiveAccount(repository);
      final balance = GetAccountBalance(repository);

      await archive(budgetId: 'budget-1', accountId: 'account-1');

      expect(repository.snapshot('budget-1', includeArchived: false), isEmpty);
      expect(
        repository.snapshot('budget-1', includeArchived: true),
        hasLength(1),
      );
      expect(
        (await balance(
          budgetId: 'budget-1',
          accountId: 'account-1',
        )).minorUnits,
        BigInt.from(12500),
      );
    },
  );
}

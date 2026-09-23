import 'package:budget_accounting_system/src/domain/errors/domain_validation_error.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/transaction_draft.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/domain/value_objects/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final eur = Currency('EUR');
  final usd = Currency('USD');

  Money eurAmount(int minorUnits) => Money.positive(
        minorUnits: BigInt.from(minorUnits),
        currency: eur,
      );

  test('accepts income without destination account', () {
    final draft = TransactionDraft(
      type: TransactionType.income,
      amount: eurAmount(1000),
      accountId: 'cash',
      accountCurrency: eur,
      categoryId: 'salary',
    );

    expect(draft.destinationAccountId, isNull);
  });

  test('requires transfer destination account', () {
    expect(
      () => TransactionDraft(
        type: TransactionType.transfer,
        amount: eurAmount(1000),
        accountId: 'cash',
        accountCurrency: eur,
      ),
      throwsA(
        isA<DomainValidationError>().having(
          (error) => error.code,
          'code',
          DomainValidationCode.missingDestinationAccount,
        ),
      ),
    );
  });

  test('rejects transfer to the same account', () {
    expect(
      () => TransactionDraft(
        type: TransactionType.transfer,
        amount: eurAmount(1000),
        accountId: 'cash',
        accountCurrency: eur,
        destinationAccountId: 'cash',
        destinationAccountCurrency: eur,
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

  test('rejects transaction when amount currency differs from source account', () {
    expect(
      () => TransactionDraft(
        type: TransactionType.expense,
        amount: eurAmount(1000),
        accountId: 'cash',
        accountCurrency: usd,
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

  test('rejects cross-currency transfer', () {
    expect(
      () => TransactionDraft(
        type: TransactionType.transfer,
        amount: eurAmount(1000),
        accountId: 'cash-eur',
        accountCurrency: eur,
        destinationAccountId: 'cash-usd',
        destinationAccountCurrency: usd,
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

  test('rejects destination account for income and expense', () {
    for (final type in [TransactionType.income, TransactionType.expense]) {
      expect(
        () => TransactionDraft(
          type: type,
          amount: eurAmount(1000),
          accountId: 'cash',
          accountCurrency: eur,
          destinationAccountId: 'bank',
        ),
        throwsA(
          isA<DomainValidationError>().having(
            (error) => error.code,
            'code',
            DomainValidationCode.unexpectedDestinationAccount,
          ),
        ),
      );
    }
  });
}

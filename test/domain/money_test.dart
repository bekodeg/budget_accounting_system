import 'package:budget_accounting_system/src/domain/errors/domain_validation_error.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:budget_accounting_system/src/domain/value_objects/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final eur = Currency('EUR');

  test('creates positive money in minor units', () {
    final money = Money.positive(
      minorUnits: BigInt.from(12345),
      currency: eur,
    );

    expect(money.minorUnits, BigInt.from(12345));
    expect(money.currency, eur);
  });

  test('rejects zero and negative amounts for transaction money', () {
    for (final value in [BigInt.zero, BigInt.from(-1)]) {
      expect(
        () => Money.positive(minorUnits: value, currency: eur),
        throwsA(
          isA<DomainValidationError>().having(
            (error) => error.code,
            'code',
            DomainValidationCode.nonPositiveAmount,
          ),
        ),
      );
    }
  });

  test('supports explicit zero for aggregate values', () {
    expect(Money.zero(eur).minorUnits, BigInt.zero);
  });
}

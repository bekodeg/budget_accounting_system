import 'package:budget_accounting_system/src/domain/errors/domain_validation_error.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes a valid three-letter currency code', () {
    expect(Currency(' eur ').code, 'EUR');
  });

  test('rejects malformed currency code', () {
    expect(
      () => Currency('EURO'),
      throwsA(
        isA<DomainValidationError>().having(
          (error) => error.code,
          'code',
          DomainValidationCode.invalidCurrency,
        ),
      ),
    );
  });
}

import '../errors/domain_validation_error.dart';
import 'currency.dart';

final class Money {
  const Money._({
    required this.minorUnits,
    required this.currency,
  });

  factory Money.positive({
    required BigInt minorUnits,
    required Currency currency,
  }) {
    if (minorUnits <= BigInt.zero) {
      throw const DomainValidationError(
        code: DomainValidationCode.nonPositiveAmount,
        message: 'Money amount must be greater than zero.',
      );
    }

    return Money._(
      minorUnits: minorUnits,
      currency: currency,
    );
  }

  factory Money.zero(Currency currency) {
    return Money._(
      minorUnits: BigInt.zero,
      currency: currency,
    );
  }

  final BigInt minorUnits;
  final Currency currency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          other.minorUnits == minorUnits &&
          other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${minorUnits.toString()} ${currency.code} minor';
}

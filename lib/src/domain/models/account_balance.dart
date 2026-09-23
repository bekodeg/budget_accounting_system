import '../value_objects/currency.dart';

final class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.minorUnits,
    required this.currency,
  });

  final String accountId;
  final BigInt minorUnits;
  final Currency currency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountBalance &&
          other.accountId == accountId &&
          other.minorUnits == minorUnits &&
          other.currency == currency;

  @override
  int get hashCode => Object.hash(accountId, minorUnits, currency);
}

enum DomainValidationCode {
  invalidCurrency,
  nonPositiveAmount,
  sameTransferAccount,
  missingDestinationAccount,
  unexpectedDestinationAccount,
  currencyMismatch,
}

final class DomainValidationError implements Exception {
  const DomainValidationError({required this.code, required this.message});

  final DomainValidationCode code;
  final String message;

  @override
  String toString() => 'DomainValidationError($code): $message';
}

enum AccountErrorCode {
  emptyName,
  accountNotFound,
  currencyLockedByTransactions,
}

final class AccountError implements Exception {
  const AccountError({
    required this.code,
    required this.message,
  });

  final AccountErrorCode code;
  final String message;

  @override
  String toString() => 'AccountError($code): $message';
}

enum TransactionErrorCode {
  transactionNotFound,
  missingCategory,
  invalidCategory,
}

final class TransactionError implements Exception {
  const TransactionError({
    required this.code,
    required this.message,
  });

  final TransactionErrorCode code;
  final String message;

  @override
  String toString() => 'TransactionError($code): $message';
}

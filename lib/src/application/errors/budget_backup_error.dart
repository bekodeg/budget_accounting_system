enum BudgetBackupErrorCode {
  invalidFormat,
  unsupportedVersion,
  wrongPasswordOrCorrupted,
  invalidSnapshot,
}

final class BudgetBackupError implements Exception {
  const BudgetBackupError(this.code, this.message);

  final BudgetBackupErrorCode code;
  final String message;

  @override
  String toString() => 'BudgetBackupError($code): $message';
}

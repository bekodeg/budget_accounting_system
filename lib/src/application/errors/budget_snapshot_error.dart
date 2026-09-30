enum BudgetSnapshotErrorCode {
  invalidFormat,
  unsupportedVersion,
  budgetMismatch,
  digestMismatch,
}

final class BudgetSnapshotError implements Exception {
  const BudgetSnapshotError(this.code, this.message);

  final BudgetSnapshotErrorCode code;
  final String message;

  @override
  String toString() => 'BudgetSnapshotError($code): $message';
}

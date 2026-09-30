enum PlanErrorCode {
  negativeAmount,
  categoryNotFound,
  categoryArchived,
  incomeCategory,
}

final class PlanError implements Exception {
  const PlanError(this.code, this.message);

  final PlanErrorCode code;
  final String message;

  @override
  String toString() => 'PlanError($code): $message';
}

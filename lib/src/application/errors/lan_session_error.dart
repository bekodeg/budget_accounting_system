enum LanSessionErrorCode {
  budgetMismatch,
  invalidSecretProof,
  invalidIdentitySignature,
  invalidHandshake,
}

final class LanSessionError implements Exception {
  const LanSessionError(this.code, this.message);

  final LanSessionErrorCode code;
  final String message;

  @override
  String toString() => 'LanSessionError($code): $message';
}

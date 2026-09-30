enum IdentityErrorCode {
  privateKeyUnavailable,
  publicKeyMismatch,
  revokedDevice,
}

final class IdentityError implements Exception {
  const IdentityError(this.code, this.message);

  final IdentityErrorCode code;
  final String message;

  @override
  String toString() => 'IdentityError($code): $message';
}

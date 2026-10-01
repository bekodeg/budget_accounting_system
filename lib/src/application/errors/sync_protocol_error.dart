enum SyncProtocolErrorCode {
  invalidMessage,
  unsupportedVersion,
  budgetMismatch,
  batchMismatch,
  operationCollision,
  unknownIdentity,
  revokedDevice,
  invalidSignature,
  remoteError,
}

final class SyncProtocolError implements Exception {
  const SyncProtocolError(this.code, this.message);

  final SyncProtocolErrorCode code;
  final String message;

  @override
  String toString() => 'SyncProtocolError($code): $message';
}

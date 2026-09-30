enum InviteErrorCode {
  invalidFormat,
  unsupportedVersion,
  invalidRole,
  expired,
  invalidSignature,
  alreadyConsumed,
  selfInvite,
  budgetConflict,
  privateKeyUnavailable,
}

final class InviteError implements Exception {
  const InviteError(this.code, this.message);

  final InviteErrorCode code;
  final String message;

  @override
  String toString() => 'InviteError($code): $message';
}

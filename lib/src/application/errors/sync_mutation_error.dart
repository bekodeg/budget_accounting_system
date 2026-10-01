enum SyncMutationErrorCode { duplicateOperation }

final class SyncMutationError implements Exception {
  const SyncMutationError(this.code, this.message);

  final SyncMutationErrorCode code;
  final String message;

  @override
  String toString() => 'SyncMutationError($code): $message';
}

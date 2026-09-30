enum SyncMergeErrorCode {
  invalidPatch,
  operationIdCollision,
  versionCollision,
}

final class SyncMergeError implements Exception {
  const SyncMergeError(this.code, this.message);

  final SyncMergeErrorCode code;
  final String message;

  @override
  String toString() => 'SyncMergeError($code): $message';
}

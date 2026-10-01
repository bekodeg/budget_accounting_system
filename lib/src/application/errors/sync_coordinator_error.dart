enum SyncCoordinatorErrorCode { noPeers, coordinatorUnavailable }

final class SyncCoordinatorError implements Exception {
  const SyncCoordinatorError(this.code, this.message, {this.deviceId});

  final SyncCoordinatorErrorCode code;
  final String message;
  final String? deviceId;

  @override
  String toString() => 'SyncCoordinatorError($code): $message';
}

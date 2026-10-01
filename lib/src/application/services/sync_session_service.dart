import '../../domain/models/sync_protocol.dart';
import '../errors/sync_protocol_error.dart';
import '../ports/secure_lan_channel.dart';
import '../ports/sync_journal.dart';
import 'sync_protocol_codec.dart';

final class SyncSessionService {
  SyncSessionService({
    required SyncJournal journal,
    SyncProtocolCodec codec = const SyncProtocolCodec(),
    this.batchSize = 100,
    DateTime Function()? now,
  }) : _journal = journal,
       _codec = codec,
       _now = now ?? _utcNow {
    if (batchSize <= 0 || batchSize > maxBatchOperations) {
      throw ArgumentError.value(
        batchSize,
        'batchSize',
        'Must be between 1 and $maxBatchOperations.',
      );
    }
  }

  static const maxBatchOperations = 100;

  final SyncJournal _journal;
  final SyncProtocolCodec _codec;
  final DateTime Function() _now;
  final int batchSize;

  Future<SyncSessionMetrics> synchronize({
    required SecureLanChannel channel,
    required String budgetId,
    required String localDeviceId,
  }) async {
    final startedAt = _now().toUtc();
    var sentOperations = 0;
    var receivedOperations = 0;
    var duplicateOperations = 0;
    var sentBatches = 0;
    var receivedBatches = 0;

    try {
      final localVector = await _journal.stateVector(budgetId);
      await _send(
        channel,
        SyncHelloMessage(
          version: SyncProtocolCodec.currentVersion,
          budgetId: budgetId,
          deviceId: localDeviceId,
          stateVector: localVector,
        ),
      );

      final remoteHello = _expectHello(
        await _receive(channel),
        budgetId: budgetId,
      );
      if (remoteHello.deviceId != channel.remotePeer.deviceId) {
        throw const SyncProtocolError(
          SyncProtocolErrorCode.invalidMessage,
          'Sync hello device does not match authenticated LAN peer.',
        );
      }

      var remoteVector = remoteHello.stateVector;
      var sequence = 0;

      while (true) {
        final page = await _journal.missingOperations(
          budgetId: budgetId,
          remoteState: remoteVector,
          limit: batchSize,
        );
        final batch = SyncOperationsBatchMessage(
          version: SyncProtocolCodec.currentVersion,
          budgetId: budgetId,
          batchId: '$localDeviceId:$sequence',
          operations: page.operations,
          hasMore: page.hasMore,
        );
        sequence += 1;

        await _send(channel, batch);
        sentBatches += 1;
        sentOperations += batch.operations.length;

        final remoteBatch = _expectBatch(
          await _receive(channel),
          budgetId: budgetId,
        );
        receivedBatches += 1;
        receivedOperations += remoteBatch.operations.length;
        if (remoteBatch.operations.length > maxBatchOperations) {
          throw SyncProtocolError(
            SyncProtocolErrorCode.invalidMessage,
            'Remote batch exceeds $maxBatchOperations operations.',
          );
        }

        final ingest = await _journal.ingest(
          budgetId: budgetId,
          operations: remoteBatch.operations,
        );
        duplicateOperations += ingest.duplicates;

        final afterIngest = await _journal.stateVector(budgetId);
        await _send(
          channel,
          SyncAckMessage(
            version: SyncProtocolCodec.currentVersion,
            budgetId: budgetId,
            batchId: remoteBatch.batchId,
            stateVector: afterIngest,
          ),
        );

        final ack = _expectAck(
          await _receive(channel),
          budgetId: budgetId,
          expectedBatchId: batch.batchId,
        );
        remoteVector = ack.stateVector;

        if (!page.hasMore && !remoteBatch.hasMore) {
          break;
        }
      }

      return SyncSessionMetrics(
        sentOperations: sentOperations,
        receivedOperations: receivedOperations,
        duplicateOperations: duplicateOperations,
        sentBatches: sentBatches,
        receivedBatches: receivedBatches,
        startedAt: startedAt,
        completedAt: _now().toUtc(),
      );
    } on SyncProtocolError catch (error) {
      if (error.code != SyncProtocolErrorCode.remoteError) {
        await _sendErrorBestEffort(channel, budgetId, error);
      }
      rethrow;
    }
  }

  Future<void> _send(SecureLanChannel channel, SyncProtocolMessage message) {
    return channel.send(_codec.encode(message));
  }

  Future<SyncProtocolMessage> _receive(SecureLanChannel channel) async {
    final message = _codec.decode(await channel.receive());
    if (message is SyncErrorMessage) {
      throw SyncProtocolError(
        SyncProtocolErrorCode.remoteError,
        'Remote sync error ${message.code}: ${message.message}',
      );
    }
    return message;
  }

  SyncHelloMessage _expectHello(
    SyncProtocolMessage message, {
    required String budgetId,
  }) {
    _requireBudget(message, budgetId);
    if (message is! SyncHelloMessage) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Expected sync hello.',
      );
    }
    return message;
  }

  SyncOperationsBatchMessage _expectBatch(
    SyncProtocolMessage message, {
    required String budgetId,
  }) {
    _requireBudget(message, budgetId);
    if (message is! SyncOperationsBatchMessage) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Expected operations batch.',
      );
    }
    return message;
  }

  SyncAckMessage _expectAck(
    SyncProtocolMessage message, {
    required String budgetId,
    required String expectedBatchId,
  }) {
    _requireBudget(message, budgetId);
    if (message is! SyncAckMessage) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Expected batch acknowledgement.',
      );
    }
    if (message.batchId != expectedBatchId) {
      throw SyncProtocolError(
        SyncProtocolErrorCode.batchMismatch,
        'Ack for ${message.batchId} does not match $expectedBatchId.',
      );
    }
    return message;
  }

  void _requireBudget(SyncProtocolMessage message, String budgetId) {
    if (message.budgetId != budgetId) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.budgetMismatch,
        'Sync message belongs to another budget.',
      );
    }
  }

  Future<void> _sendErrorBestEffort(
    SecureLanChannel channel,
    String budgetId,
    SyncProtocolError error,
  ) async {
    try {
      await _send(
        channel,
        SyncErrorMessage(
          version: SyncProtocolCodec.currentVersion,
          budgetId: budgetId,
          code: error.code.name,
          message: error.message,
        ),
      );
    } on Object {
      // The transport may already be gone; the local error remains authoritative.
    }
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

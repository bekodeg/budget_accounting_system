import 'sync_mutation.dart';

final class SyncStateVector {
  SyncStateVector(Map<String, BigInt> clocks)
    : clocks = Map.unmodifiable(clocks);

  const SyncStateVector.empty() : clocks = const {};

  final Map<String, BigInt> clocks;

  BigInt clockFor(String deviceId) => clocks[deviceId] ?? BigInt.zero;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SyncStateVector || other.clocks.length != clocks.length) {
      return false;
    }
    for (final entry in clocks.entries) {
      if (other.clocks[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final entries = clocks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Object.hashAll(
      entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
  }
}

final class SyncWireOperation {
  const SyncWireOperation({
    required this.operation,
    required this.signature,
  });

  final SignedSyncOperation operation;
  final String signature;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncWireOperation &&
          _sameOperation(operation, other.operation) &&
          signature == other.signature;

  @override
  int get hashCode => Object.hash(
    operation.operationId,
    operation.budgetId,
    operation.entityType,
    operation.entityId,
    operation.type,
    operation.patchJson,
    operation.authorId,
    operation.deviceId,
    operation.logicalClock,
    operation.createdAt,
    signature,
  );
}

final class SyncOperationPage {
  const SyncOperationPage({
    required this.operations,
    required this.hasMore,
  });

  final List<SyncWireOperation> operations;
  final bool hasMore;
}

final class SyncIngestResult {
  const SyncIngestResult({
    required this.inserted,
    required this.duplicates,
  });

  final int inserted;
  final int duplicates;
}

sealed class SyncProtocolMessage {
  const SyncProtocolMessage({
    required this.version,
    required this.budgetId,
  });

  final int version;
  final String budgetId;
}

final class SyncHelloMessage extends SyncProtocolMessage {
  const SyncHelloMessage({
    required super.version,
    required super.budgetId,
    required this.deviceId,
    required this.stateVector,
  });

  final String deviceId;
  final SyncStateVector stateVector;
}

final class SyncOperationsBatchMessage extends SyncProtocolMessage {
  const SyncOperationsBatchMessage({
    required super.version,
    required super.budgetId,
    required this.batchId,
    required this.operations,
    required this.hasMore,
  });

  final String batchId;
  final List<SyncWireOperation> operations;
  final bool hasMore;
}

final class SyncAckMessage extends SyncProtocolMessage {
  const SyncAckMessage({
    required super.version,
    required super.budgetId,
    required this.batchId,
    required this.stateVector,
  });

  final String batchId;
  final SyncStateVector stateVector;
}

final class SyncErrorMessage extends SyncProtocolMessage {
  const SyncErrorMessage({
    required super.version,
    required super.budgetId,
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

final class SyncSessionMetrics {
  const SyncSessionMetrics({
    required this.sentOperations,
    required this.receivedOperations,
    required this.duplicateOperations,
    required this.sentBatches,
    required this.receivedBatches,
    required this.startedAt,
    required this.completedAt,
  });

  final int sentOperations;
  final int receivedOperations;
  final int duplicateOperations;
  final int sentBatches;
  final int receivedBatches;
  final DateTime startedAt;
  final DateTime completedAt;

  Duration get duration => completedAt.difference(startedAt);
}

bool _sameOperation(
  SignedSyncOperation left,
  SignedSyncOperation right,
) {
  return left.operationId == right.operationId &&
      left.budgetId == right.budgetId &&
      left.entityType == right.entityType &&
      left.entityId == right.entityId &&
      left.type == right.type &&
      left.patchJson == right.patchJson &&
      left.authorId == right.authorId &&
      left.deviceId == right.deviceId &&
      left.logicalClock == right.logicalClock &&
      left.createdAt == right.createdAt;
}

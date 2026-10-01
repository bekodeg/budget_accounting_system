enum SyncMutationType {
  create,
  patch,
  delete,
}

final class SyncMutationSpec {
  const SyncMutationSpec({
    required this.budgetId,
    required this.entityType,
    required this.entityId,
    required this.type,
    required this.patch,
    this.operationId,
  });

  final String budgetId;
  final String entityType;
  final String entityId;
  final SyncMutationType type;
  final Map<String, Object?> patch;
  final String? operationId;
}

final class SyncMutationDraft {
  const SyncMutationDraft({
    required this.spec,
    required this.authorId,
    required this.deviceId,
  });

  final SyncMutationSpec spec;
  final String authorId;
  final String deviceId;
}

final class SignedSyncOperation {
  const SignedSyncOperation({
    required this.operationId,
    required this.budgetId,
    required this.entityType,
    required this.entityId,
    required this.type,
    required this.patchJson,
    required this.authorId,
    required this.deviceId,
    required this.logicalClock,
    required this.createdAt,
  });

  final String operationId;
  final String budgetId;
  final String entityType;
  final String entityId;
  final SyncMutationType type;
  final String patchJson;
  final String authorId;
  final String deviceId;
  final BigInt logicalClock;
  final DateTime createdAt;
}

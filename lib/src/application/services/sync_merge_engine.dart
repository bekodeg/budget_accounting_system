import 'dart:convert';

import '../../domain/models/sync_merge_state.dart';
import '../../domain/models/sync_mutation.dart';
import '../errors/sync_merge_error.dart';
import 'sync_operation_codec.dart';

final class SyncMergeEngine {
  const SyncMergeEngine({SyncOperationCodec codec = const SyncOperationCodec()})
    : _codec = codec;

  final SyncOperationCodec _codec;

  MergedSyncEntityState merge(Iterable<SignedSyncOperation> operations) {
    final fields = <String, SyncFieldState>{};
    final fingerprintsByOperationId = <String, String>{};
    final operationIdByVersion = <SyncVersion, String>{};
    final appliedOperationIds = <String>{};
    String? budgetId;
    String? entityType;
    String? entityId;
    SyncVersion? tombstoneVersion;
    SyncVersion? latestWriteVersion;

    for (final operation in operations) {
      final fingerprint = base64Url.encode(_codec.signingBytes(operation));
      final previousFingerprint =
          fingerprintsByOperationId[operation.operationId];
      if (previousFingerprint != null) {
        if (previousFingerprint != fingerprint) {
          throw SyncMergeError(
            SyncMergeErrorCode.operationIdCollision,
            'Один op_id используется для разных операций: '
            '${operation.operationId}.',
          );
        }
        continue;
      }

      fingerprintsByOperationId[operation.operationId] = fingerprint;
      appliedOperationIds.add(operation.operationId);

      budgetId ??= operation.budgetId;
      entityType ??= operation.entityType;
      entityId ??= operation.entityId;
      if (operation.budgetId != budgetId ||
          operation.entityType != entityType ||
          operation.entityId != entityId) {
        throw const SyncMergeError(
          SyncMergeErrorCode.mixedEntity,
          'Один merge может содержать операции только одной сущности бюджета.',
        );
      }

      final version = SyncVersion(
        logicalClock: operation.logicalClock,
        deviceId: operation.deviceId,
      );

      final previousOperationId = operationIdByVersion[version];
      if (previousOperationId != null &&
          previousOperationId != operation.operationId) {
        throw SyncMergeError(
          SyncMergeErrorCode.versionCollision,
          'Устройство ${operation.deviceId} выпустило разные операции '
          'с Lamport clock ${operation.logicalClock}.',
        );
      }
      operationIdByVersion[version] = operation.operationId;

      if (operation.type == SyncMutationType.delete) {
        if (version.isNewerThan(tombstoneVersion)) {
          tombstoneVersion = version;
        }
        continue;
      }

      if (version.isNewerThan(latestWriteVersion)) {
        latestWriteVersion = version;
      }

      final patch = _decodePatch(operation.patchJson);
      for (final entry in patch.entries) {
        final current = fields[entry.key];
        if (current == null || version.isNewerThan(current.version)) {
          fields[entry.key] = SyncFieldState(
            value: entry.value,
            version: version,
            operationId: operation.operationId,
          );
          continue;
        }

        if (version == current.version &&
            !_deepEquals(entry.value, current.value)) {
          throw SyncMergeError(
            SyncMergeErrorCode.versionCollision,
            'Две операции с одинаковой версией изменяют поле '
            '${entry.key} по-разному.',
          );
        }
      }
    }

    return MergedSyncEntityState(
      fields: Map.unmodifiable(fields),
      tombstoneVersion: tombstoneVersion,
      latestWriteVersion: latestWriteVersion,
      appliedOperationIds: Set.unmodifiable(appliedOperationIds),
    );
  }

  Map<String, Object?> _decodePatch(String patchJson) {
    Object? decoded;
    try {
      decoded = jsonDecode(patchJson);
    } on FormatException {
      throw const SyncMergeError(
        SyncMergeErrorCode.invalidPatch,
        'Patch операции должен быть корректным JSON object.',
      );
    }

    if (decoded is! Map) {
      throw const SyncMergeError(
        SyncMergeErrorCode.invalidPatch,
        'Patch операции должен быть JSON object.',
      );
    }

    return {
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
  }
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key)) return false;
      if (!_deepEquals(entry.value, right[entry.key])) return false;
    }
    return true;
  }
  return left == right;
}

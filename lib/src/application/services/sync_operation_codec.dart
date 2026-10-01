import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/sync_mutation.dart';

final class SyncOperationCodec {
  const SyncOperationCodec();

  String encodePatch(Map<String, Object?> patch) {
    return _canonicalJson(patch);
  }

  Uint8List signingBytes(SignedSyncOperation operation) {
    final value = {
      'op_id': operation.operationId,
      'budget_id': operation.budgetId,
      'entity_type': operation.entityType,
      'entity_id': operation.entityId,
      'op_type': _typeName(operation.type),
      'patch': jsonDecode(operation.patchJson),
      'author_id': operation.authorId,
      'device_id': operation.deviceId,
      'logical_clock': operation.logicalClock.toString(),
      'created_at': operation.createdAt.toUtc().toIso8601String(),
    };
    return Uint8List.fromList(utf8.encode(_canonicalJson(value)));
  }
}

String _canonicalJson(Object? value) {
  Object? sort(Object? current) {
    if (current is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in current.entries) {
        sorted[entry.key.toString()] = sort(entry.value);
      }
      return sorted;
    }
    if (current is List) {
      return current.map(sort).toList(growable: false);
    }
    if (current is BigInt) {
      return current.toString();
    }
    if (current is DateTime) {
      return current.toUtc().toIso8601String();
    }
    return current;
  }

  return jsonEncode(sort(value));
}

String syncMutationTypeName(SyncMutationType type) => _typeName(type);

String _typeName(SyncMutationType type) {
  return switch (type) {
    SyncMutationType.create => 'CREATE',
    SyncMutationType.patch => 'PATCH',
    SyncMutationType.delete => 'DELETE',
  };
}

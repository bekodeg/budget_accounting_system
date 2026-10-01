import 'dart:convert';

import '../../domain/models/sync_mutation.dart';
import '../../domain/models/sync_protocol.dart';
import '../errors/sync_protocol_error.dart';

final class SyncProtocolCodec {
  const SyncProtocolCodec();

  static const currentVersion = 1;

  List<int> encode(SyncProtocolMessage message) {
    final base = <String, Object?>{
      'v': message.version,
      'budget_id': message.budgetId,
    };

    final value = switch (message) {
      final SyncHelloMessage hello => {
        ...base,
        'type': 'hello',
        'device_id': hello.deviceId,
        'state_vector': _encodeVector(hello.stateVector),
      },
      final SyncOperationsBatchMessage batch => {
        ...base,
        'type': 'batch',
        'batch_id': batch.batchId,
        'has_more': batch.hasMore,
        'operations': batch.operations.map(_encodeOperation).toList(),
      },
      final SyncAckMessage ack => {
        ...base,
        'type': 'ack',
        'batch_id': ack.batchId,
        'state_vector': _encodeVector(ack.stateVector),
      },
      final SyncErrorMessage error => {
        ...base,
        'type': 'error',
        'code': error.code,
        'message': error.message,
      },
    };

    return utf8.encode(jsonEncode(value));
  }

  SyncProtocolMessage decode(List<int> bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Sync frame is not valid UTF-8 JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Sync frame must be a JSON object.',
      );
    }

    final version = decoded['v'];
    if (version is! int) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Sync frame version is missing.',
      );
    }
    if (version != currentVersion) {
      throw SyncProtocolError(
        SyncProtocolErrorCode.unsupportedVersion,
        'Unsupported sync protocol version: $version.',
      );
    }

    final budgetId = _string(decoded, 'budget_id');
    final type = _string(decoded, 'type');

    return switch (type) {
      'hello' => SyncHelloMessage(
        version: version,
        budgetId: budgetId,
        deviceId: _string(decoded, 'device_id'),
        stateVector: _decodeVector(decoded['state_vector']),
      ),
      'batch' => SyncOperationsBatchMessage(
        version: version,
        budgetId: budgetId,
        batchId: _string(decoded, 'batch_id'),
        operations: _decodeOperations(decoded['operations']),
        hasMore: _bool(decoded, 'has_more'),
      ),
      'ack' => SyncAckMessage(
        version: version,
        budgetId: budgetId,
        batchId: _string(decoded, 'batch_id'),
        stateVector: _decodeVector(decoded['state_vector']),
      ),
      'error' => SyncErrorMessage(
        version: version,
        budgetId: budgetId,
        code: _string(decoded, 'code'),
        message: _string(decoded, 'message'),
      ),
      _ => throw SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Unknown sync frame type: $type.',
      ),
    };
  }

  Map<String, String> _encodeVector(SyncStateVector vector) {
    final devices = vector.clocks.keys.toList()..sort();
    return {
      for (final deviceId in devices)
        deviceId: vector.clocks[deviceId]!.toString(),
    };
  }

  SyncStateVector _decodeVector(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'State vector must be an object.',
      );
    }

    final clocks = <String, BigInt>{};
    for (final entry in raw.entries) {
      if (entry.key.isEmpty || entry.value is! String) {
        throw const SyncProtocolError(
          SyncProtocolErrorCode.invalidMessage,
          'State vector contains an invalid entry.',
        );
      }
      final clock = BigInt.tryParse(entry.value as String);
      if (clock == null || clock.isNegative) {
        throw const SyncProtocolError(
          SyncProtocolErrorCode.invalidMessage,
          'State vector clock must be a non-negative integer.',
        );
      }
      clocks[entry.key] = clock;
    }
    return SyncStateVector(clocks);
  }

  Map<String, Object?> _encodeOperation(SyncWireOperation wire) {
    final operation = wire.operation;
    return {
      'op_id': operation.operationId,
      'budget_id': operation.budgetId,
      'entity_type': operation.entityType,
      'entity_id': operation.entityId,
      'op_type': _typeName(operation.type),
      'patch_json': operation.patchJson,
      'author_id': operation.authorId,
      'device_id': operation.deviceId,
      'logical_clock': operation.logicalClock.toString(),
      'created_at': operation.createdAt.toUtc().toIso8601String(),
      'signature': wire.signature,
    };
  }

  List<SyncWireOperation> _decodeOperations(Object? raw) {
    if (raw is! List) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Operations batch must contain an array.',
      );
    }
    return raw.map(_decodeOperation).toList(growable: false);
  }

  SyncWireOperation _decodeOperation(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Sync operation must be an object.',
      );
    }

    final clock = BigInt.tryParse(_string(raw, 'logical_clock'));
    if (clock == null || clock.isNegative) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Operation logical clock is invalid.',
      );
    }

    final createdAt = DateTime.tryParse(_string(raw, 'created_at'));
    if (createdAt == null) {
      throw const SyncProtocolError(
        SyncProtocolErrorCode.invalidMessage,
        'Operation created_at is invalid.',
      );
    }

    return SyncWireOperation(
      operation: SignedSyncOperation(
        operationId: _string(raw, 'op_id'),
        budgetId: _string(raw, 'budget_id'),
        entityType: _string(raw, 'entity_type'),
        entityId: _string(raw, 'entity_id'),
        type: _type(_string(raw, 'op_type')),
        patchJson: _string(raw, 'patch_json'),
        authorId: _string(raw, 'author_id'),
        deviceId: _string(raw, 'device_id'),
        logicalClock: clock,
        createdAt: createdAt.toUtc(),
      ),
      signature: _string(raw, 'signature'),
    );
  }
}

String _string(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw SyncProtocolError(
      SyncProtocolErrorCode.invalidMessage,
      'Sync frame field $key must be a non-empty string.',
    );
  }
  return result;
}

bool _bool(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! bool) {
    throw SyncProtocolError(
      SyncProtocolErrorCode.invalidMessage,
      'Sync frame field $key must be a boolean.',
    );
  }
  return result;
}

SyncMutationType _type(String value) {
  return switch (value) {
    'CREATE' => SyncMutationType.create,
    'PATCH' => SyncMutationType.patch,
    'DELETE' => SyncMutationType.delete,
    _ => throw SyncProtocolError(
      SyncProtocolErrorCode.invalidMessage,
      'Unsupported operation type: $value.',
    ),
  };
}

String _typeName(SyncMutationType type) {
  return switch (type) {
    SyncMutationType.create => 'CREATE',
    SyncMutationType.patch => 'PATCH',
    SyncMutationType.delete => 'DELETE',
  };
}

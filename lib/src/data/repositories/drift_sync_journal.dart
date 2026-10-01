import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/errors/sync_protocol_error.dart';
import '../../application/ports/identity_signature_service.dart';
import '../../application/ports/sync_journal.dart';
import '../../application/services/sync_operation_codec.dart';
import '../../domain/models/sync_mutation.dart';
import '../../domain/models/sync_protocol.dart';
import '../../domain/repositories/identity_repository.dart';
import '../dal/sync_dao.dart';
import '../database/app_database.dart';
import '../services/drift_sync_materializer.dart';

final class DriftSyncJournal implements SyncJournal {
  const DriftSyncJournal({
    required AppDatabase database,
    required SyncDao syncDao,
    required IdentityRepository identityRepository,
    required IdentitySignatureService signatureService,
    required DriftSyncMaterializer materializer,
    SyncOperationCodec operationCodec = const SyncOperationCodec(),
  }) : _database = database,
       _syncDao = syncDao,
       _identityRepository = identityRepository,
       _signatureService = signatureService,
       _materializer = materializer,
       _operationCodec = operationCodec;

  final AppDatabase _database;
  final SyncDao _syncDao;
  final IdentityRepository _identityRepository;
  final IdentitySignatureService _signatureService;
  final DriftSyncMaterializer _materializer;
  final SyncOperationCodec _operationCodec;

  @override
  Future<SyncStateVector> stateVector(String budgetId) async {
    return SyncStateVector(await _syncDao.getStateVector(budgetId));
  }

  @override
  Future<SyncOperationPage> missingOperations({
    required String budgetId,
    required SyncStateVector remoteState,
    required int limit,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }

    final localState = await _syncDao.getStateVector(budgetId);
    final devices = localState.keys.toList()..sort();
    final candidates = <SyncOperation>[];

    for (final deviceId in devices) {
      final remoteClock = remoteState.clockFor(deviceId);
      final localClock = localState[deviceId] ?? BigInt.zero;
      if (localClock <= remoteClock) continue;

      final remaining = limit + 1 - candidates.length;
      if (remaining <= 0) break;

      candidates.addAll(
        await _syncDao.getDeviceOperationsAfter(
          budgetId: budgetId,
          deviceId: deviceId,
          logicalClock: remoteClock,
          limit: remaining,
        ),
      );
      if (candidates.length > limit) break;
    }

    candidates.sort((left, right) {
      final clock = left.logicalClock.compareTo(right.logicalClock);
      if (clock != 0) return clock;
      final device = left.deviceId.compareTo(right.deviceId);
      if (device != 0) return device;
      return left.opId.compareTo(right.opId);
    });

    final hasMore = candidates.length > limit;
    final page = candidates.take(limit).map(_toWire).toList(growable: false);
    return SyncOperationPage(operations: page, hasMore: hasMore);
  }

  @override
  Future<SyncIngestResult> ingest({
    required String budgetId,
    required List<SyncWireOperation> operations,
  }) {
    return _database.transaction(() async {
      var inserted = 0;
      var duplicates = 0;
      final touchedEntities = <SyncEntityRef>{};

      for (final wire in operations) {
        final operation = wire.operation;
        if (operation.budgetId != budgetId) {
          throw const SyncProtocolError(
            SyncProtocolErrorCode.budgetMismatch,
            'Remote operation belongs to another budget.',
          );
        }

        final existing = await _syncDao.findById(operation.operationId);
        if (existing != null) {
          if (!_matchesStoredOperation(existing, wire)) {
            throw SyncProtocolError(
              SyncProtocolErrorCode.operationCollision,
              'Remote op_id collision: ${operation.operationId}.',
            );
          }
          duplicates += 1;
          continue;
        }

        final publicKey = await _identityRepository.getUserPublicKey(
          operation.authorId,
        );
        if (publicKey == null || publicKey.startsWith('local-unverified:')) {
          throw SyncProtocolError(
            SyncProtocolErrorCode.unknownIdentity,
            'Unknown author identity: ${operation.authorId}.',
          );
        }

        final device = await _identityRepository.findDevice(operation.deviceId);
        if (device == null || device.userId != operation.authorId) {
          throw SyncProtocolError(
            SyncProtocolErrorCode.unknownIdentity,
            'Unknown author device: ${operation.deviceId}.',
          );
        }
        if (device.isRevoked) {
          throw SyncProtocolError(
            SyncProtocolErrorCode.revokedDevice,
            'Author device is revoked: ${operation.deviceId}.',
          );
        }

        final valid = await _signatureService.verify(
          publicKey: publicKey,
          message: _operationCodec.signingBytes(operation),
          signature: wire.signature,
        );
        if (!valid) {
          throw SyncProtocolError(
            SyncProtocolErrorCode.invalidSignature,
            'Invalid signature for operation ${operation.operationId}.',
          );
        }

        Uint8List signatureBytes;
        try {
          signatureBytes = base64Url.decode(wire.signature);
        } on FormatException {
          throw const SyncProtocolError(
            SyncProtocolErrorCode.invalidSignature,
            'Operation signature is not valid base64url.',
          );
        }

        await _syncDao.appendStrict(
          SyncOperationsCompanion.insert(
            opId: operation.operationId,
            budgetId: operation.budgetId,
            entityType: operation.entityType,
            entityId: operation.entityId,
            opType: syncMutationTypeName(operation.type),
            patch: operation.patchJson,
            authorId: operation.authorId,
            deviceId: operation.deviceId,
            logicalClock: operation.logicalClock,
            signature: signatureBytes,
            createdAt: Value(operation.createdAt),
          ),
        );
        inserted += 1;
        touchedEntities.add(
          SyncEntityRef(operation.entityType, operation.entityId),
        );
      }

      if (touchedEntities.isNotEmpty) {
        await _materializer.materialize(
          budgetId: budgetId,
          entities: touchedEntities,
        );
      }

      return SyncIngestResult(inserted: inserted, duplicates: duplicates);
    });
  }

  bool _matchesStoredOperation(SyncOperation stored, SyncWireOperation wire) {
    final operation = wire.operation;
    if (stored.opId != operation.operationId ||
        stored.budgetId != operation.budgetId ||
        stored.entityType != operation.entityType ||
        stored.entityId != operation.entityId ||
        stored.opType != syncMutationTypeName(operation.type) ||
        stored.patch != operation.patchJson ||
        stored.authorId != operation.authorId ||
        stored.deviceId != operation.deviceId ||
        stored.logicalClock != operation.logicalClock ||
        stored.createdAt != operation.createdAt) {
      return false;
    }

    Uint8List incomingSignature;
    try {
      incomingSignature = base64Url.decode(wire.signature);
    } on FormatException {
      return false;
    }
    if (stored.signature.length != incomingSignature.length) {
      return false;
    }
    for (var index = 0; index < stored.signature.length; index += 1) {
      if (stored.signature[index] != incomingSignature[index]) {
        return false;
      }
    }
    return true;
  }

  SyncWireOperation _toWire(SyncOperation row) {
    return SyncWireOperation(
      operation: SignedSyncOperation(
        operationId: row.opId,
        budgetId: row.budgetId,
        entityType: row.entityType,
        entityId: row.entityId,
        type: _typeFromStorage(row.opType),
        patchJson: row.patch,
        authorId: row.authorId,
        deviceId: row.deviceId,
        logicalClock: row.logicalClock,
        createdAt: row.createdAt,
      ),
      signature: base64Url.encode(row.signature),
    );
  }
}

SyncMutationType _typeFromStorage(String value) {
  return switch (value) {
    'CREATE' => SyncMutationType.create,
    'PATCH' => SyncMutationType.patch,
    'DELETE' => SyncMutationType.delete,
    _ => throw StateError('Unsupported sync operation type: $value'),
  };
}

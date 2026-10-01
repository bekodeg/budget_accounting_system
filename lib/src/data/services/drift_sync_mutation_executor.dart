import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/errors/sync_mutation_error.dart';
import '../../application/ports/id_generator.dart';
import '../../application/ports/identity_signature_service.dart';
import '../../application/ports/sync_mutation_executor.dart';
import '../../application/services/sync_operation_codec.dart';
import '../../domain/models/sync_mutation.dart';
import '../dal/sync_dao.dart';
import '../database/app_database.dart';

final class DriftSyncMutationExecutor implements SyncMutationExecutor {
  const DriftSyncMutationExecutor({
    required AppDatabase database,
    required SyncDao syncDao,
    required IdGenerator idGenerator,
    required IdentitySignatureService signatureService,
    SyncOperationCodec codec = const SyncOperationCodec(),
  }) : _database = database,
       _syncDao = syncDao,
       _idGenerator = idGenerator,
       _signatureService = signatureService,
       _codec = codec;

  final AppDatabase _database;
  final SyncDao _syncDao;
  final IdGenerator _idGenerator;
  final IdentitySignatureService _signatureService;
  final SyncOperationCodec _codec;

  @override
  Future<T> execute<T>({
    required SyncMutationDraft draft,
    required Future<T> Function() mutate,
    bool Function(T result)? shouldRecord,
  }) {
    return _database.transaction(() async {
      final operationId = draft.spec.operationId ?? _idGenerator.nextId();
      if (await _syncDao.findById(operationId) != null) {
        throw const SyncMutationError(
          SyncMutationErrorCode.duplicateOperation,
          'Операция синхронизации с таким op_id уже существует.',
        );
      }

      final currentClock = await _syncDao.getMaxLogicalClockForDevice(
        draft.deviceId,
      );
      final logicalClock = currentClock + BigInt.one;
      final createdAt = DateTime.now().toUtc();
      final operation = SignedSyncOperation(
        operationId: operationId,
        budgetId: draft.spec.budgetId,
        entityType: draft.spec.entityType,
        entityId: draft.spec.entityId,
        type: draft.spec.type,
        patchJson: _codec.encodePatch(draft.spec.patch),
        authorId: draft.authorId,
        deviceId: draft.deviceId,
        logicalClock: logicalClock,
        createdAt: createdAt,
      );

      final signature = await _signatureService.sign(
        deviceId: draft.deviceId,
        message: _codec.signingBytes(operation),
      );

      final result = await mutate();
      if (shouldRecord != null && !shouldRecord(result)) {
        return result;
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
          signature: base64Url.decode(signature),
          createdAt: Value(operation.createdAt),
        ),
      );

      return result;
    });
  }
}

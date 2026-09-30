import '../../domain/models/sync_protocol.dart';

abstract interface class SyncJournal {
  Future<SyncStateVector> stateVector(String budgetId);

  Future<SyncOperationPage> missingOperations({
    required String budgetId,
    required SyncStateVector remoteState,
    required int limit,
  });

  Future<SyncIngestResult> ingest({
    required String budgetId,
    required List<SyncWireOperation> operations,
  });
}

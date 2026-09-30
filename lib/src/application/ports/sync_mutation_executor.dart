import '../../domain/models/sync_mutation.dart';

abstract interface class SyncMutationExecutor {
  Future<T> execute<T>({
    required SyncMutationDraft draft,
    required Future<T> Function() mutate,
  });
}

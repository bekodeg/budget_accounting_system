import '../../domain/models/public_identity.dart';

final class SyncMutationContext {
  const SyncMutationContext({required this.userId, required this.identity});

  final String userId;
  final PublicIdentity identity;
}

abstract interface class SyncMutationContextProvider {
  Future<SyncMutationContext> current();
}

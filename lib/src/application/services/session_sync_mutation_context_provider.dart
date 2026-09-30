import '../ports/session_store.dart';
import '../ports/sync_mutation_context_provider.dart';
import '../use_cases/get_public_identity.dart';

final class SessionSyncMutationContextProvider
    implements SyncMutationContextProvider {
  const SessionSyncMutationContextProvider({
    required SessionStore sessionStore,
    required GetPublicIdentity getPublicIdentity,
  }) : _sessionStore = sessionStore,
       _getPublicIdentity = getPublicIdentity;

  final SessionStore _sessionStore;
  final GetPublicIdentity _getPublicIdentity;

  @override
  Future<SyncMutationContext> current() async {
    final userId = await _sessionStore.loadCurrentUserId();
    if (userId == null) {
      throw StateError('Current user is required for synchronized mutation.');
    }
    final identity = await _getPublicIdentity(userId);
    return SyncMutationContext(userId: userId, identity: identity);
  }
}

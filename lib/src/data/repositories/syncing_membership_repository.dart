import '../../application/ports/sync_mutation_context_provider.dart';
import '../../application/ports/sync_mutation_executor.dart';
import '../../domain/models/budget_member_profile.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/sync_mutation.dart';
import '../../domain/repositories/membership_repository.dart';

final class SyncingMembershipRepository implements MembershipRepository {
  const SyncingMembershipRepository({
    required MembershipRepository delegate,
    required SyncMutationExecutor executor,
    required SyncMutationContextProvider contextProvider,
  }) : _delegate = delegate,
       _executor = executor,
       _contextProvider = contextProvider;

  final MembershipRepository _delegate;
  final SyncMutationExecutor _executor;
  final SyncMutationContextProvider _contextProvider;

  @override
  Future<BudgetMemberProfile?> findActiveMember({
    required String budgetId,
    required String userId,
  }) =>
      _delegate.findActiveMember(budgetId: budgetId, userId: userId);

  @override
  Stream<List<BudgetMemberProfile>> watchMembers(String budgetId) =>
      _delegate.watchMembers(budgetId);

  @override
  Future<int> countActiveOwners(String budgetId) =>
      _delegate.countActiveOwners(budgetId);

  @override
  Future<bool> updateMemberRole({
    required String budgetId,
    required String userId,
    required MemberRole role,
  }) async {
    final context = await _contextProvider.current();
    return _executor.execute<bool>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: budgetId,
          entityType: 'budget_member',
          entityId: '$budgetId:$userId',
          type: SyncMutationType.patch,
          patch: {'role': role.name.toUpperCase()},
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.updateMemberRole(
        budgetId: budgetId,
        userId: userId,
        role: role,
      ),
      shouldRecord: (changed) => changed,
    );
  }
}

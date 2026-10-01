import '../../domain/models/budget_member_profile.dart';
import '../../domain/models/sync_mutation.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../ports/sync_mutation_executor.dart';
import 'get_public_identity.dart';

final class RunBudgetMutation {
  const RunBudgetMutation({
    required BudgetAuthorizationGuard authorization,
    required GetPublicIdentity getPublicIdentity,
    required SyncMutationExecutor executor,
  }) : _authorization = authorization,
       _getPublicIdentity = getPublicIdentity,
       _executor = executor;

  final BudgetAuthorizationGuard _authorization;
  final GetPublicIdentity _getPublicIdentity;
  final SyncMutationExecutor _executor;

  Future<T> call<T>({
    required SyncMutationSpec spec,
    BudgetAction action = BudgetAction.mutate,
    required Future<T> Function(BudgetMemberProfile member) mutate,
  }) async {
    final member = await _authorization.require(
      budgetId: spec.budgetId,
      action: action,
    );
    final identity = await _getPublicIdentity(member.userId);

    return _executor.execute(
      draft: SyncMutationDraft(
        spec: spec,
        authorId: member.userId,
        deviceId: identity.deviceId,
      ),
      mutate: () => mutate(member),
    );
  }
}

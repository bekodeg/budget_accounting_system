import '../../domain/models/domain_types.dart';
import '../../domain/repositories/membership_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/authorization_error.dart';

final class UpdateMemberRole {
  const UpdateMemberRole({
    required MembershipRepository membershipRepository,
    required BudgetAuthorizationGuard authorization,
  }) : _membershipRepository = membershipRepository,
       _authorization = authorization;

  final MembershipRepository _membershipRepository;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String userId,
    required MemberRole role,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.manageMembers,
    );

    final target = await _membershipRepository.findActiveMember(
      budgetId: budgetId,
      userId: userId,
    );
    if (target == null) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.notMember,
        message: 'Участник бюджета не найден.',
      );
    }

    if (target.role == MemberRole.owner && role != MemberRole.owner) {
      final ownerCount = await _membershipRepository.countActiveOwners(budgetId);
      if (ownerCount <= 1) {
        throw const AuthorizationError(
          code: AuthorizationErrorCode.lastOwner,
          message: 'В бюджете должен остаться хотя бы один владелец.',
        );
      }
    }

    if (target.role == role) return;

    final updated = await _membershipRepository.updateMemberRole(
      budgetId: budgetId,
      userId: userId,
      role: role,
    );
    if (!updated) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.notMember,
        message: 'Участник бюджета не найден.',
      );
    }
  }
}

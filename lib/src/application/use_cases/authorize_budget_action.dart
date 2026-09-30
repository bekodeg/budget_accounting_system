import '../../domain/models/budget_member_profile.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/membership_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/authorization_error.dart';
import '../ports/session_store.dart';

final class AuthorizeBudgetAction implements BudgetAuthorizationGuard {
  const AuthorizeBudgetAction({
    required MembershipRepository membershipRepository,
    required SessionStore sessionStore,
  }) : _membershipRepository = membershipRepository,
       _sessionStore = sessionStore;

  final MembershipRepository _membershipRepository;
  final SessionStore _sessionStore;

  @override
  Future<BudgetMemberProfile> require({
    required String budgetId,
    required BudgetAction action,
  }) async {
    final userId = await _sessionStore.loadCurrentUserId();
    if (userId == null) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.unauthenticated,
        message: 'Локальная пользовательская сессия не найдена.',
      );
    }

    final member = await _membershipRepository.findActiveMember(
      budgetId: budgetId,
      userId: userId,
    );
    if (member == null) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.notMember,
        message: 'Пользователь не является участником этого бюджета.',
      );
    }

    if (!_allows(member.role, action)) {
      throw AuthorizationError(
        code: AuthorizationErrorCode.forbidden,
        message:
            'Роль ${member.role.name.toUpperCase()} не разрешает это действие.',
      );
    }
    return member;
  }
}

bool _allows(MemberRole role, BudgetAction action) {
  return switch (role) {
    MemberRole.owner => true,
    MemberRole.editor => action != BudgetAction.manageMembers,
    MemberRole.viewer =>
      action == BudgetAction.read || action == BudgetAction.export,
  };
}

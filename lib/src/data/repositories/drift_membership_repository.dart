import '../../domain/models/budget_member_profile.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/membership_repository.dart';
import '../dal/user_budget_dao.dart';

final class DriftMembershipRepository implements MembershipRepository {
  const DriftMembershipRepository(this._dao);

  final UserBudgetDao _dao;

  @override
  Future<BudgetMemberProfile?> findActiveMember({
    required String budgetId,
    required String userId,
  }) async {
    final row = await _dao.findActiveMember(budgetId: budgetId, userId: userId);
    return row == null ? null : _toDomain(row);
  }

  @override
  Stream<List<BudgetMemberProfile>> watchMembers(String budgetId) {
    return _dao
        .watchActiveMembers(budgetId)
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<int> countActiveOwners(String budgetId) {
    return _dao.countActiveOwners(budgetId);
  }

  @override
  Future<bool> updateMemberRole({
    required String budgetId,
    required String userId,
    required MemberRole role,
  }) {
    return _dao.updateMemberRole(
      budgetId: budgetId,
      userId: userId,
      role: _roleToStorage(role),
    );
  }

  BudgetMemberProfile _toDomain(MembershipRow row) {
    return BudgetMemberProfile(
      userId: row.user.id,
      name: row.user.name,
      role: _roleFromStorage(row.member.role),
      joinedAt: row.member.joinedAt,
      revokedAt: row.member.revokedAt,
    );
  }
}

MemberRole _roleFromStorage(String value) {
  return switch (value) {
    'OWNER' => MemberRole.owner,
    'EDITOR' => MemberRole.editor,
    'VIEWER' => MemberRole.viewer,
    _ => throw StateError('Unsupported membership role: $value'),
  };
}

String _roleToStorage(MemberRole role) {
  return switch (role) {
    MemberRole.owner => 'OWNER',
    MemberRole.editor => 'EDITOR',
    MemberRole.viewer => 'VIEWER',
  };
}

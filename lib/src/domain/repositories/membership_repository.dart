import '../models/budget_member_profile.dart';
import '../models/domain_types.dart';

abstract interface class MembershipRepository {
  Future<BudgetMemberProfile?> findActiveMember({
    required String budgetId,
    required String userId,
  });

  Stream<List<BudgetMemberProfile>> watchMembers(String budgetId);

  Future<int> countActiveOwners(String budgetId);

  Future<bool> updateMemberRole({
    required String budgetId,
    required String userId,
    required MemberRole role,
  });
}

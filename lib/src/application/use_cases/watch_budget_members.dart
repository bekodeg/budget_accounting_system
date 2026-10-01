import '../../domain/models/budget_member_profile.dart';
import '../../domain/repositories/membership_repository.dart';

final class WatchBudgetMembers {
  const WatchBudgetMembers(this._repository);

  final MembershipRepository _repository;

  Stream<List<BudgetMemberProfile>> call(String budgetId) {
    return _repository.watchMembers(budgetId);
  }
}

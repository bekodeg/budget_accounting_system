import '../models/budget_invite.dart';
import '../models/budget_summary.dart';
import '../models/public_identity.dart';

abstract interface class InvitationRepository {
  Future<BudgetSummary?> findBudget(String budgetId);

  Future<void> acceptInvite({
    required BudgetInvite invite,
    required PublicIdentity joiningIdentity,
  });
}

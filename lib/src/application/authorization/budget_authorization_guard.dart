import '../../domain/models/budget_member_profile.dart';
import 'budget_action.dart';

abstract interface class BudgetAuthorizationGuard {
  Future<BudgetMemberProfile> require({
    required String budgetId,
    required BudgetAction action,
  });
}

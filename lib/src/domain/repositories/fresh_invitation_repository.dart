import '../models/budget_invite.dart';
import '../models/public_identity.dart';

abstract interface class FreshInvitationRepository {
  Future<void> acceptInviteForNewIdentity({
    required BudgetInvite invite,
    required String joiningUserName,
    required PublicIdentity joiningIdentity,
  });
}

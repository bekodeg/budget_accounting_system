import '../../domain/models/budget_invite.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../errors/invite_error.dart';
import '../ports/invite_consumption_store.dart';
import '../ports/session_store.dart';
import 'get_public_identity.dart';
import 'inspect_budget_invite.dart';

final class AcceptBudgetInvite {
  const AcceptBudgetInvite({
    required InspectBudgetInvite inspectInvite,
    required InvitationRepository invitationRepository,
    required InviteConsumptionStore consumptionStore,
    required SessionStore sessionStore,
    required GetPublicIdentity getPublicIdentity,
  }) : _inspectInvite = inspectInvite,
       _invitationRepository = invitationRepository,
       _consumptionStore = consumptionStore,
       _sessionStore = sessionStore,
       _getPublicIdentity = getPublicIdentity;

  final InspectBudgetInvite _inspectInvite;
  final InvitationRepository _invitationRepository;
  final InviteConsumptionStore _consumptionStore;
  final SessionStore _sessionStore;
  final GetPublicIdentity _getPublicIdentity;

  Future<BudgetInvitePreview> call(String rawPayload) async {
    final preview = await _inspectInvite(rawPayload);
    final invite = preview.invite;

    final userId = await _sessionStore.loadCurrentUserId();
    if (userId == null) {
      throw StateError('Local user session is required to accept an invite.');
    }
    if (userId == invite.ownerUserId) {
      throw const InviteError(
        InviteErrorCode.selfInvite,
        'Владелец не может принять собственное приглашение.',
      );
    }

    final joiningIdentity = await _getPublicIdentity(userId);

    await _consumptionStore.markConsumed(invite.inviteId);
    try {
      await _invitationRepository.acceptInvite(
        invite: invite,
        joiningIdentity: joiningIdentity,
      );
    } on StateError catch (error) {
      await _consumptionStore.unmarkConsumed(invite.inviteId);
      throw InviteError(InviteErrorCode.budgetConflict, error.message);
    } on Object {
      await _consumptionStore.unmarkConsumed(invite.inviteId);
      rethrow;
    }

    await _sessionStore.saveCurrentBudgetId(invite.budgetId);
    return preview;
  }
}

import '../../domain/models/budget_invite.dart';
import '../../domain/models/public_identity.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../errors/invite_error.dart';
import '../ports/id_generator.dart';
import '../ports/identity_key_pair_generator.dart';
import '../ports/identity_key_store.dart';
import '../ports/invite_consumption_store.dart';
import '../ports/session_store.dart';
import '../services/budget_transport_secret_manager.dart';
import 'get_public_identity.dart';
import 'inspect_budget_invite.dart';

final class AcceptBudgetInvite {
  const AcceptBudgetInvite({
    required InspectBudgetInvite inspectInvite,
    required InvitationRepository invitationRepository,
    required InviteConsumptionStore consumptionStore,
    required SessionStore sessionStore,
    required GetPublicIdentity getPublicIdentity,
    required BudgetTransportSecretManager transportSecretManager,
    required IdGenerator idGenerator,
    required IdentityKeyStore identityKeyStore,
    required IdentityKeyPairGenerator identityKeyPairGenerator,
  }) : _inspectInvite = inspectInvite,
       _invitationRepository = invitationRepository,
       _consumptionStore = consumptionStore,
       _sessionStore = sessionStore,
       _getPublicIdentity = getPublicIdentity,
       _transportSecretManager = transportSecretManager,
       _idGenerator = idGenerator,
       _identityKeyStore = identityKeyStore,
       _identityKeyPairGenerator = identityKeyPairGenerator;

  final InspectBudgetInvite _inspectInvite;
  final InvitationRepository _invitationRepository;
  final InviteConsumptionStore _consumptionStore;
  final SessionStore _sessionStore;
  final GetPublicIdentity _getPublicIdentity;
  final BudgetTransportSecretManager _transportSecretManager;
  final IdGenerator _idGenerator;
  final IdentityKeyStore _identityKeyStore;
  final IdentityKeyPairGenerator _identityKeyPairGenerator;

  Future<BudgetInvitePreview> call(
    String rawPayload, {
    String? joiningUserName,
  }) async {
    final preview = await _inspectInvite(rawPayload);
    final invite = preview.invite;

    final storedUserId = await _sessionStore.loadCurrentUserId();
    final isNewIdentity = storedUserId == null;
    late final PublicIdentity joiningIdentity;

    if (isNewIdentity) {
      final normalizedName = joiningUserName?.trim() ?? '';
      if (normalizedName.isEmpty) {
        throw const InviteError(
          InviteErrorCode.budgetConflict,
          'Введите имя пользователя перед присоединением к бюджету.',
        );
      }

      final userId = _idGenerator.nextId();
      final deviceId = _idGenerator.nextId();
      final keyPair = await _identityKeyPairGenerator.generate();
      await _identityKeyStore.saveIdentity(
        userId: userId,
        deviceId: deviceId,
        privateKey: keyPair.privateKey,
      );
      joiningIdentity = PublicIdentity(
        userId: userId,
        deviceId: deviceId,
        publicKey: keyPair.publicKey,
      );
    } else {
      if (storedUserId == invite.ownerUserId) {
        throw const InviteError(
          InviteErrorCode.selfInvite,
          'Владелец не может принять собственное приглашение.',
        );
      }
      joiningIdentity = await _getPublicIdentity(storedUserId);
    }

    await _consumptionStore.markConsumed(invite.inviteId);
    var importedTransportSecret = false;
    try {
      importedTransportSecret = await _transportSecretManager.import(
        budgetId: invite.budgetId,
        secret: invite.crypto.bootstrapSecret,
      );
      await _invitationRepository.acceptInvite(
        invite: invite,
        joiningIdentity: joiningIdentity,
        joiningUserName: isNewIdentity ? joiningUserName!.trim() : null,
      );
    } on StateError catch (error) {
      if (importedTransportSecret) {
        await _transportSecretManager.remove(invite.budgetId);
      }
      await _consumptionStore.unmarkConsumed(invite.inviteId);
      if (isNewIdentity) {
        await _identityKeyStore.deleteIdentity(
          userId: joiningIdentity.userId,
          deviceId: joiningIdentity.deviceId,
        );
      }
      throw InviteError(InviteErrorCode.budgetConflict, error.message);
    } on Object {
      if (importedTransportSecret) {
        await _transportSecretManager.remove(invite.budgetId);
      }
      await _consumptionStore.unmarkConsumed(invite.inviteId);
      if (isNewIdentity) {
        await _identityKeyStore.deleteIdentity(
          userId: joiningIdentity.userId,
          deviceId: joiningIdentity.deviceId,
        );
      }
      rethrow;
    }

    try {
      await _sessionStore.saveSession(
        userId: joiningIdentity.userId,
        budgetId: invite.budgetId,
      );
    } on Object {
      // Drift membership is authoritative. Startup can reconstruct the session.
    }
    return preview;
  }
}

import '../../domain/models/budget_invite.dart';
import '../../domain/models/public_identity.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../errors/onboarding_error.dart';
import '../ports/id_generator.dart';
import '../ports/identity_key_pair_generator.dart';
import '../ports/identity_key_store.dart';
import '../ports/invite_consumption_store.dart';
import '../ports/session_store.dart';
import '../services/budget_transport_secret_manager.dart';
import 'inspect_budget_invite.dart';

final class JoinBudgetFromInvite {
  const JoinBudgetFromInvite({
    required InspectBudgetInvite inspectInvite,
    required InvitationRepository invitationRepository,
    required InviteConsumptionStore consumptionStore,
    required SessionStore sessionStore,
    required BudgetTransportSecretManager transportSecretManager,
    required IdGenerator idGenerator,
    required IdentityKeyStore identityKeyStore,
    required IdentityKeyPairGenerator identityKeyPairGenerator,
  }) : _inspectInvite = inspectInvite,
       _invitationRepository = invitationRepository,
       _consumptionStore = consumptionStore,
       _sessionStore = sessionStore,
       _transportSecretManager = transportSecretManager,
       _idGenerator = idGenerator,
       _identityKeyStore = identityKeyStore,
       _identityKeyPairGenerator = identityKeyPairGenerator;

  final InspectBudgetInvite _inspectInvite;
  final InvitationRepository _invitationRepository;
  final InviteConsumptionStore _consumptionStore;
  final SessionStore _sessionStore;
  final BudgetTransportSecretManager _transportSecretManager;
  final IdGenerator _idGenerator;
  final IdentityKeyStore _identityKeyStore;
  final IdentityKeyPairGenerator _identityKeyPairGenerator;

  Future<BudgetInvitePreview> call({
    required String userName,
    required String rawPayload,
  }) async {
    final normalizedName = userName.trim();
    if (normalizedName.isEmpty) {
      throw const OnboardingError(
        code: OnboardingErrorCode.emptyUserName,
        message: 'Имя пользователя не может быть пустым.',
      );
    }
    if (await _sessionStore.loadCurrentUserId() != null) {
      throw StateError('Fresh-device invite flow requires an empty local session.');
    }

    final preview = await _inspectInvite(rawPayload);
    final invite = preview.invite;
    final userId = _idGenerator.nextId();
    final deviceId = _idGenerator.nextId();
    final keyPair = await _identityKeyPairGenerator.generate();
    final identity = PublicIdentity(
      userId: userId,
      deviceId: deviceId,
      publicKey: keyPair.publicKey,
    );

    await _identityKeyStore.saveIdentity(
      userId: userId,
      deviceId: deviceId,
      privateKey: keyPair.privateKey,
    );

    var consumed = false;
    var importedTransportSecret = false;
    try {
      await _consumptionStore.markConsumed(invite.inviteId);
      consumed = true;
      importedTransportSecret = await _transportSecretManager.import(
        budgetId: invite.budgetId,
        secret: invite.crypto.bootstrapSecret,
      );
      await _invitationRepository.acceptInviteForNewIdentity(
        invite: invite,
        joiningUserName: normalizedName,
        joiningIdentity: identity,
      );
    } on Object {
      if (importedTransportSecret) {
        await _transportSecretManager.remove(invite.budgetId);
      }
      if (consumed) {
        await _consumptionStore.unmarkConsumed(invite.inviteId);
      }
      await _identityKeyStore.deleteIdentity(
        userId: userId,
        deviceId: deviceId,
      );
      rethrow;
    }

    try {
      await _sessionStore.saveSession(
        userId: userId,
        budgetId: invite.budgetId,
      );
    } on Object {
      // Drift state is authoritative. Startup can reconstruct this selection.
    }

    return preview;
  }
}

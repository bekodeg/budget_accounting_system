import '../../domain/models/budget_invite.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/invite_error.dart';
import '../ports/id_generator.dart';
import '../ports/identity_signature_service.dart';
import '../ports/secure_token_generator.dart';
import '../services/budget_invite_codec.dart';
import '../services/budget_transport_secret_manager.dart';
import 'get_public_identity.dart';

final class CreateBudgetInvite {
  CreateBudgetInvite({
    required InvitationRepository invitationRepository,
    required BudgetAuthorizationGuard authorization,
    required GetPublicIdentity getPublicIdentity,
    required IdentitySignatureService signatureService,
    required SecureTokenGenerator tokenGenerator,
    required BudgetTransportSecretManager transportSecretManager,
    required IdGenerator idGenerator,
    BudgetInviteCodec codec = const BudgetInviteCodec(),
    DateTime Function()? now,
  }) : _invitationRepository = invitationRepository,
       _authorization = authorization,
       _getPublicIdentity = getPublicIdentity,
       _signatureService = signatureService,
       _tokenGenerator = tokenGenerator,
       _transportSecretManager = transportSecretManager,
       _idGenerator = idGenerator,
       _codec = codec,
       _now = now ?? _utcNow;

  final InvitationRepository _invitationRepository;
  final BudgetAuthorizationGuard _authorization;
  final GetPublicIdentity _getPublicIdentity;
  final IdentitySignatureService _signatureService;
  final SecureTokenGenerator _tokenGenerator;
  final BudgetTransportSecretManager _transportSecretManager;
  final IdGenerator _idGenerator;
  final BudgetInviteCodec _codec;
  final DateTime Function() _now;

  Future<BudgetInvitePreview> call({
    required String budgetId,
    required MemberRole role,
    Duration validFor = const Duration(hours: 24),
  }) async {
    if (role == MemberRole.owner) {
      throw const InviteError(
        InviteErrorCode.invalidRole,
        'Приглашение можно создать только для EDITOR или VIEWER.',
      );
    }
    if (validFor <= Duration.zero) {
      throw ArgumentError.value(validFor, 'validFor', 'Must be positive.');
    }

    final owner = await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.manageMembers,
    );
    final budget = await _invitationRepository.findBudget(budgetId);
    if (budget == null) {
      throw StateError('Budget not found: $budgetId');
    }
    final identity = await _getPublicIdentity(owner.userId);
    final transportSecret = await _transportSecretManager.getOrCreate(budgetId);
    final issuedAt = _now().toUtc();

    final invite = BudgetInvite(
      version: BudgetInvite.currentVersion,
      inviteId: _idGenerator.nextId(),
      budgetId: budget.id,
      budgetName: budget.name,
      baseCurrency: budget.baseCurrency,
      ownerUserId: owner.userId,
      ownerName: owner.name,
      ownerDeviceId: identity.deviceId,
      ownerPublicKey: identity.publicKey,
      role: role,
      nonce: _tokenGenerator.nextToken(bytes: 16),
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(validFor),
      crypto: InviteCryptoParameters(
        signatureAlgorithm: 'ed25519',
        kdf: 'hkdf-sha256',
        transportCipher: 'chacha20-poly1305',
        salt: _tokenGenerator.nextToken(bytes: 16),
        bootstrapSecret: transportSecret,
      ),
      signature: '',
    );

    final signature = await _signatureService.sign(
      deviceId: identity.deviceId,
      message: _codec.unsignedBytes(invite),
    );
    final signed = invite.withSignature(signature);
    return BudgetInvitePreview(
      invite: signed,
      rawPayload: _codec.encode(signed),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

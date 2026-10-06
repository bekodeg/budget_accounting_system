import 'package:budget_accounting_system/src/application/errors/invite_error.dart';
import 'package:budget_accounting_system/src/application/services/budget_invite_codec.dart';
import 'package:budget_accounting_system/src/application/services/budget_transport_secret_manager.dart';
import 'package:budget_accounting_system/src/application/use_cases/accept_budget_invite.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_budget_invite.dart';
import 'package:budget_accounting_system/src/application/use_cases/ensure_local_identity.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_public_identity.dart';
import 'package:budget_accounting_system/src/application/use_cases/inspect_budget_invite.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/local_device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 9, 30, 10);

  GetPublicIdentity identityFor({
    required String userId,
    required String deviceId,
    required String publicKey,
    required FakeIdentityRepository repository,
    required FakeIdentityKeyStore keyStore,
  }) {
    repository.publicKeysByUser[userId] = publicKey;
    repository.devicesById[deviceId] = LocalDevice(
      id: deviceId,
      userId: userId,
      revokedAt: null,
    );
    keyStore.deviceByUser[userId] = deviceId;
    keyStore.privateKeyByDevice[deviceId] = 'private-test-key';
    return GetPublicIdentity(
      EnsureLocalIdentity(
        identityRepository: repository,
        keyStore: keyStore,
        keyPairGenerator: FakeIdentityKeyPairGenerator(
          publicKey: publicKey,
          privateKey: 'private-test-key',
        ),
        idGenerator: FakeIdGenerator(const []),
      ),
    );
  }

  test(
    'creates versioned signed EDITOR invitation and validates preview',
    () async {
      final identities = FakeIdentityRepository();
      final keys = FakeIdentityKeyStore();
      final getOwnerIdentity = identityFor(
        userId: 'owner-1',
        deviceId: 'owner-device',
        publicKey: 'ed25519:owner-public',
        repository: identities,
        keyStore: keys,
      );
      final signatures = FakeIdentitySignatureService();
      final consumed = FakeInviteConsumptionStore();
      final invitations = FakeInvitationRepository();
      final transportSecrets = FakeBudgetTransportSecretStore();
      final transportSecretManager = BudgetTransportSecretManager(
        store: transportSecrets,
        tokenGenerator: FakeSecureTokenGenerator(),
      );
      final create = CreateBudgetInvite(
        invitationRepository: invitations,
        authorization: FakeBudgetAuthorizationGuard(
          userId: 'owner-1',
          role: MemberRole.owner,
        ),
        getPublicIdentity: getOwnerIdentity,
        signatureService: signatures,
        tokenGenerator: FakeSecureTokenGenerator(),
        transportSecretManager: transportSecretManager,
        idGenerator: FakeIdGenerator(['invite-1']),
        now: () => fixedNow,
      );
      final inspect = InspectBudgetInvite(
        signatureService: signatures,
        consumptionStore: consumed,
        now: () => fixedNow.add(const Duration(minutes: 1)),
      );

      final generated = await create(
        budgetId: 'budget-1',
        role: MemberRole.editor,
      );
      final preview = await inspect(generated.rawPayload);

      expect(preview.invite.version, 1);
      expect(preview.invite.inviteId, 'invite-1');
      expect(preview.invite.role, MemberRole.editor);
      expect(preview.invite.ownerUserId, 'owner-1');
      expect(preview.invite.ownerDeviceId, 'owner-device');
      expect(preview.invite.crypto.signatureAlgorithm, 'ed25519');
      expect(preview.invite.crypto.kdf, 'hkdf-sha256');
      expect(preview.invite.crypto.transportCipher, 'chacha20-poly1305');
      expect(
        await transportSecrets.load('budget-1'),
        preview.invite.crypto.bootstrapSecret,
      );
      expect(preview.invite.expiresAt, fixedNow.add(const Duration(hours: 24)));
    },
  );

  test('fresh join rolls back external state when persistence fails', () async {
    final ownerServices = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(currentUserId: 'owner-1'),
      idGenerator: FakeIdGenerator(['owner-device', 'invite-1']),
    );
    final generated = await ownerServices.createBudgetInvite(
      budgetId: 'budget-1',
      role: MemberRole.editor,
    );

    final session = FakeSessionStore();
    final keys = FakeIdentityKeyStore();
    final consumed = FakeInviteConsumptionStore();
    final transportSecrets = FakeBudgetTransportSecretStore();
    final invitations = FakeInvitationRepository(
      acceptNewIdentityError: StateError('database unavailable'),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: session,
      invitationRepository: invitations,
      identityKeyStore: keys,
      inviteConsumptionStore: consumed,
      transportSecretStore: transportSecrets,
      idGenerator: FakeIdGenerator(['user-2', 'device-2']),
    );

    await expectLater(
      services.joinBudgetFromInvite!(
        userName: 'Bob',
        rawPayload: generated.rawPayload,
      ),
      throwsStateError,
    );

    expect(keys.deviceByUser, isEmpty);
    expect(keys.privateKeyByDevice, isEmpty);
    expect(consumed.consumed, isEmpty);
    expect(await transportSecrets.load('budget-1'), isNull);
    expect(await session.loadCurrentUserId(), isNull);
    expect(await session.loadCurrentBudgetId(), isNull);
    expect(invitations.accepted, isEmpty);
  });

  test('rejects tampered signature and expired invite', () async {
    final codec = const BudgetInviteCodec();
    final identities = FakeIdentityRepository();
    final keys = FakeIdentityKeyStore();
    final signatures = FakeIdentitySignatureService();
    final consumed = FakeInviteConsumptionStore();
    final transportSecrets = FakeBudgetTransportSecretStore();
    final transportSecretManager = BudgetTransportSecretManager(
      store: transportSecrets,
      tokenGenerator: FakeSecureTokenGenerator(),
    );
    final create = CreateBudgetInvite(
      invitationRepository: FakeInvitationRepository(),
      authorization: FakeBudgetAuthorizationGuard(
        userId: 'owner-1',
        role: MemberRole.owner,
      ),
      getPublicIdentity: identityFor(
        userId: 'owner-1',
        deviceId: 'owner-device',
        publicKey: 'ed25519:owner-public',
        repository: identities,
        keyStore: keys,
      ),
      signatureService: signatures,
      tokenGenerator: FakeSecureTokenGenerator(),
      transportSecretManager: transportSecretManager,
      idGenerator: FakeIdGenerator(['invite-1']),
      now: () => fixedNow,
    );
    final generated = await create(
      budgetId: 'budget-1',
      role: MemberRole.viewer,
      validFor: const Duration(minutes: 10),
    );

    final decoded = codec.decode(generated.rawPayload);
    final tampered = codec.encode(decoded.withSignature('invalid'));

    await expectLater(
      InspectBudgetInvite(
        signatureService: signatures,
        consumptionStore: consumed,
        now: () => fixedNow.add(const Duration(minutes: 1)),
      )(tampered),
      throwsA(
        isA<InviteError>().having(
          (error) => error.code,
          'code',
          InviteErrorCode.invalidSignature,
        ),
      ),
    );

    await expectLater(
      InspectBudgetInvite(
        signatureService: signatures,
        consumptionStore: consumed,
        now: () => fixedNow.add(const Duration(minutes: 10)),
      )(generated.rawPayload),
      throwsA(
        isA<InviteError>().having(
          (error) => error.code,
          'code',
          InviteErrorCode.expired,
        ),
      ),
    );
  });

  test('second identity accepts invite offline only once', () async {
    final ownerIdentities = FakeIdentityRepository();
    final ownerKeys = FakeIdentityKeyStore();
    final signatures = FakeIdentitySignatureService();
    final consumed = FakeInviteConsumptionStore();
    final invitations = FakeInvitationRepository();
    final ownerTransportSecrets = FakeBudgetTransportSecretStore();
    final ownerTransportSecretManager = BudgetTransportSecretManager(
      store: ownerTransportSecrets,
      tokenGenerator: FakeSecureTokenGenerator(),
    );
    final create = CreateBudgetInvite(
      invitationRepository: invitations,
      authorization: FakeBudgetAuthorizationGuard(
        userId: 'owner-1',
        role: MemberRole.owner,
      ),
      getPublicIdentity: identityFor(
        userId: 'owner-1',
        deviceId: 'owner-device',
        publicKey: 'ed25519:owner-public',
        repository: ownerIdentities,
        keyStore: ownerKeys,
      ),
      signatureService: signatures,
      tokenGenerator: FakeSecureTokenGenerator(),
      transportSecretManager: ownerTransportSecretManager,
      idGenerator: FakeIdGenerator(['invite-1']),
      now: () => fixedNow,
    );
    final generated = await create(
      budgetId: 'budget-1',
      role: MemberRole.viewer,
    );

    final joiningIdentities = FakeIdentityRepository();
    final joiningKeys = FakeIdentityKeyStore();
    final getJoiningIdentity = identityFor(
      userId: 'user-2',
      deviceId: 'device-2',
      publicKey: 'ed25519:user-2-public',
      repository: joiningIdentities,
      keyStore: joiningKeys,
    );
    final inspect = InspectBudgetInvite(
      signatureService: signatures,
      consumptionStore: consumed,
      now: () => fixedNow.add(const Duration(minutes: 1)),
    );
    final session = FakeSessionStore(currentUserId: 'user-2');
    final joiningTransportSecrets = FakeBudgetTransportSecretStore();
    final joiningTransportSecretManager = BudgetTransportSecretManager(
      store: joiningTransportSecrets,
      tokenGenerator: FakeSecureTokenGenerator(),
    );
    final accept = AcceptBudgetInvite(
      inspectInvite: inspect,
      invitationRepository: invitations,
      consumptionStore: consumed,
      sessionStore: session,
      getPublicIdentity: getJoiningIdentity,
      transportSecretManager: joiningTransportSecretManager,
    );

    final accepted = await accept(generated.rawPayload);

    expect(accepted.invite.budgetId, 'budget-1');
    expect(invitations.accepted, hasLength(1));
    expect(invitations.accepted.single.joiningIdentity.userId, 'user-2');
    expect(await session.loadCurrentBudgetId(), 'budget-1');
    expect(
      await joiningTransportSecrets.load('budget-1'),
      generated.invite.crypto.bootstrapSecret,
    );

    await expectLater(
      accept(generated.rawPayload),
      throwsA(
        isA<InviteError>().having(
          (error) => error.code,
          'code',
          InviteErrorCode.alreadyConsumed,
        ),
      ),
    );
  });
}

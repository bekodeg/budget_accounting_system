import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_invitation_repository.dart';
import 'package:budget_accounting_system/src/domain/models/budget_invite.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/public_identity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao dao;
  late DriftInvitationRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    dao = UserBudgetDao(database);
    repository = DriftInvitationRepository(dao);

    await dao.upsertUser(
      UsersCompanion.insert(
        id: 'user-2',
        name: 'Bob',
        publicKey: 'ed25519:user-2-public',
      ),
    );
    await database.into(database.devices).insert(
      DevicesCompanion.insert(
        id: 'device-2',
        userId: 'user-2',
      ),
    );
  });

  tearDown(() => database.close());

  BudgetInvite invite() => BudgetInvite(
    version: 1,
    inviteId: 'invite-1',
    budgetId: 'budget-shared',
    budgetName: 'Shared home',
    baseCurrency: 'EUR',
    ownerUserId: 'owner-1',
    ownerName: 'Alice',
    ownerDeviceId: 'owner-device',
    ownerPublicKey: 'ed25519:owner-public',
    role: MemberRole.editor,
    nonce: 'nonce',
    issuedAt: DateTime.utc(2026, 9, 30),
    expiresAt: DateTime.utc(2026, 10, 1),
    crypto: const InviteCryptoParameters(
      signatureAlgorithm: 'ed25519',
      kdf: 'hkdf-sha256',
      transportCipher: 'chacha20-poly1305',
      salt: 'salt',
      bootstrapSecret: 'secret',
    ),
    signature: 'signature',
  );

  test('accepts invite offline and creates budget memberships atomically', () async {
    await repository.acceptInvite(
      invite: invite(),
      joiningIdentity: const PublicIdentity(
        userId: 'user-2',
        deviceId: 'device-2',
        publicKey: 'ed25519:user-2-public',
      ),
    );

    final budget = await dao.findBudgetById('budget-shared');
    final owner = await dao.findUserById('owner-1');
    final ownerDevice = await dao.findDeviceById('owner-device');
    final members = await dao.getMembers('budget-shared');

    expect(budget?.name, 'Shared home');
    expect(budget?.createdBy, 'owner-1');
    expect(owner?.publicKey, 'ed25519:owner-public');
    expect(ownerDevice?.userId, 'owner-1');
    expect(
      members.singleWhere((member) => member.userId == 'owner-1').role,
      'OWNER',
    );
    expect(
      members.singleWhere((member) => member.userId == 'user-2').role,
      'EDITOR',
    );
  });

  test('rejects conflicting owner public identity', () async {
    await dao.upsertUser(
      UsersCompanion.insert(
        id: 'owner-1',
        name: 'Mallory',
        publicKey: 'ed25519:different-key',
      ),
    );

    await expectLater(
      repository.acceptInvite(
        invite: invite(),
        joiningIdentity: const PublicIdentity(
          userId: 'user-2',
          deviceId: 'device-2',
          publicKey: 'ed25519:user-2-public',
        ),
      ),
      throwsStateError,
    );

    expect(await dao.findBudgetById('budget-shared'), isNull);
  });
}

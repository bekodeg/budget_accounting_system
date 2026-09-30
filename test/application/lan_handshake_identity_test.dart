import 'package:budget_accounting_system/src/application/errors/lan_session_error.dart';
import 'package:budget_accounting_system/src/application/services/budget_transport_secret_manager.dart';
import 'package:budget_accounting_system/src/application/services/lan_handshake_service.dart';
import 'package:budget_accounting_system/src/domain/models/local_device.dart';
import 'package:budget_accounting_system/src/domain/models/public_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  const budgetId = 'budget-1';
  const secret = 'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=';

  test('known revoked device is rejected after cryptographic proof', () async {
    final remote = _handshake(secret: secret);
    final hello = await remote.create(
      budgetId: budgetId,
      identity: const PublicIdentity(
        userId: 'member-1',
        deviceId: 'member-device',
        publicKey: 'ed25519:member',
      ),
    );

    final identities = FakeIdentityRepository(
      publicKeysByUser: const {'member-1': 'ed25519:member'},
      devicesById: {
        'member-device': LocalDevice(
          id: 'member-device',
          userId: 'member-1',
          revokedAt: DateTime.utc(2026, 9, 30),
        ),
      },
    );
    final trusted = _handshake(
      secret: secret,
      identityRepository: identities,
    );

    await expectLater(
      trusted.verify(expectedBudgetId: budgetId, hello: hello),
      throwsA(
        isA<LanSessionError>().having(
          (error) => error.code,
          'code',
          LanSessionErrorCode.revokedDevice,
        ),
      ),
    );
  });

  test('known public key mismatch is rejected', () async {
    final remote = _handshake(secret: secret);
    final hello = await remote.create(
      budgetId: budgetId,
      identity: const PublicIdentity(
        userId: 'member-1',
        deviceId: 'member-device',
        publicKey: 'ed25519:unexpected',
      ),
    );

    final trusted = _handshake(
      secret: secret,
      identityRepository: FakeIdentityRepository(
        publicKeysByUser: const {'member-1': 'ed25519:known'},
      ),
    );

    await expectLater(
      trusted.verify(expectedBudgetId: budgetId, hello: hello),
      throwsA(
        isA<LanSessionError>().having(
          (error) => error.code,
          'code',
          LanSessionErrorCode.identityMismatch,
        ),
      ),
    );
  });
}

LanHandshakeService _handshake({
  required String secret,
  FakeIdentityRepository? identityRepository,
}) {
  final store = FakeBudgetTransportSecretStore()
    ..secretsByBudget['budget-1'] = secret;
  return LanHandshakeService(
    transportSecretManager: BudgetTransportSecretManager(
      store: store,
      tokenGenerator: FakeSecureTokenGenerator(),
    ),
    signatureService: FakeIdentitySignatureService(),
    tokenGenerator: FakeSecureTokenGenerator(),
    identityRepository: identityRepository,
  );
}

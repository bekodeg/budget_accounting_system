import 'package:budget_accounting_system/src/application/errors/identity_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/ensure_local_identity.dart';
import 'package:budget_accounting_system/src/domain/models/local_device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  test('migrates legacy identity once and keeps it stable on restart', () async {
    final repository = FakeIdentityRepository(
      publicKeysByUser: {'user-1': 'local-unverified:user-1'},
    );
    final keyStore = FakeIdentityKeyStore();
    final generator = FakeIdentityKeyPairGenerator();
    final useCase = EnsureLocalIdentity(
      identityRepository: repository,
      keyStore: keyStore,
      keyPairGenerator: generator,
      idGenerator: FakeIdGenerator(['device-1']),
    );

    final first = await useCase('user-1');
    final second = await useCase('user-1');

    expect(first, second);
    expect(first.deviceId, 'device-1');
    expect(first.publicKey, 'ed25519:public-test-key');
    expect(repository.publicKeysByUser['user-1'], first.publicKey);
    expect(repository.devicesById.keys, ['device-1']);
    expect(keyStore.deviceByUser['user-1'], 'device-1');
    expect(keyStore.privateKeyByDevice['device-1'], 'private-test-key');
  });

  test('returns existing identity without generating a new device', () async {
    final repository = FakeIdentityRepository(
      publicKeysByUser: {'user-1': 'ed25519:public-test-key'},
      devicesById: {
        'device-1': const LocalDevice(
          id: 'device-1',
          userId: 'user-1',
          revokedAt: null,
        ),
      },
    );
    final keyStore = FakeIdentityKeyStore()
      ..deviceByUser['user-1'] = 'device-1'
      ..privateKeyByDevice['device-1'] = 'private-test-key';
    final useCase = EnsureLocalIdentity(
      identityRepository: repository,
      keyStore: keyStore,
      keyPairGenerator: FakeIdentityKeyPairGenerator(),
      idGenerator: FakeIdGenerator(const []),
    );

    final identity = await useCase('user-1');

    expect(identity.userId, 'user-1');
    expect(identity.deviceId, 'device-1');
    expect(identity.publicKey, 'ed25519:public-test-key');
  });

  test('rejects revoked local device', () async {
    final repository = FakeIdentityRepository(
      publicKeysByUser: {'user-1': 'ed25519:public-test-key'},
      devicesById: {
        'device-1': LocalDevice(
          id: 'device-1',
          userId: 'user-1',
          revokedAt: DateTime(2026, 9, 30),
        ),
      },
    );
    final keyStore = FakeIdentityKeyStore()
      ..deviceByUser['user-1'] = 'device-1'
      ..privateKeyByDevice['device-1'] = 'private-test-key';
    final useCase = EnsureLocalIdentity(
      identityRepository: repository,
      keyStore: keyStore,
      keyPairGenerator: FakeIdentityKeyPairGenerator(),
      idGenerator: FakeIdGenerator(const []),
    );

    await expectLater(
      useCase('user-1'),
      throwsA(
        isA<IdentityError>().having(
          (error) => error.code,
          'code',
          IdentityErrorCode.revokedDevice,
        ),
      ),
    );
  });
}

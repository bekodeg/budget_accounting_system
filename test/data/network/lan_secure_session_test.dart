import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/application/errors/lan_session_error.dart';
import 'package:budget_accounting_system/src/application/ports/budget_transport_secret_store.dart';
import 'package:budget_accounting_system/src/application/ports/identity_signature_service.dart';
import 'package:budget_accounting_system/src/application/ports/secure_token_generator.dart';
import 'package:budget_accounting_system/src/application/services/budget_transport_secret_manager.dart';
import 'package:budget_accounting_system/src/application/services/lan_handshake_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_secure_session_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_session_crypto.dart';
import 'package:budget_accounting_system/src/data/network/tcp_lan_transport_gateway.dart';
import 'package:budget_accounting_system/src/domain/models/public_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const budgetId = 'budget-1';
  final sharedSecret = base64Url.encode(
    List<int>.generate(32, (index) => index + 1),
  );

  test('two TCP peers authenticate and exchange encrypted frames', () async {
    final ownerManager = await _manager(sharedSecret);
    final memberManager = await _manager(sharedSecret);
    final ownerSession = _sessionService(
      manager: ownerManager,
      nonce: 'owner-nonce',
    );
    final memberSession = _sessionService(
      manager: memberManager,
      nonce: 'member-nonce',
    );
    const transport = TcpLanTransportGateway();
    final listener = await transport.listen();

    try {
      final serverChannelFuture = listener.connections.first;
      final clientRaw = await transport.connect(
        host: '127.0.0.1',
        port: listener.port,
      );
      final serverRaw = await serverChannelFuture;

      final ownerIdentity = const PublicIdentity(
        userId: 'owner-1',
        deviceId: 'owner-device',
        publicKey: 'ed25519:owner',
      );
      final memberIdentity = const PublicIdentity(
        userId: 'member-1',
        deviceId: 'member-device',
        publicKey: 'ed25519:member',
      );

      final serverFuture = ownerSession.accept(
        channel: serverRaw,
        budgetId: budgetId,
        identity: ownerIdentity,
      );
      final clientFuture = memberSession.initiate(
        channel: clientRaw,
        budgetId: budgetId,
        identity: memberIdentity,
      );
      final channels = await Future.wait([serverFuture, clientFuture]);
      final server = channels[0];
      final client = channels[1];

      expect(server.remotePeer.deviceId, 'member-device');
      expect(client.remotePeer.deviceId, 'owner-device');

      await client.send(utf8.encode('hello owner'));
      expect(utf8.decode(await server.receive()), 'hello owner');

      await server.send(utf8.encode('hello member'));
      expect(utf8.decode(await client.receive()), 'hello member');

      await client.close();
      await server.close();
    } finally {
      await listener.close();
    }
  });

  test('peer with another budget secret is rejected', () async {
    final trustedManager = await _manager(sharedSecret);
    final foreignManager = await _manager(
      base64Url.encode(List<int>.filled(32, 99)),
    );
    final trusted = _handshake(manager: trustedManager, nonce: 'trusted-nonce');
    final foreign = _handshake(manager: foreignManager, nonce: 'foreign-nonce');

    final hello = await foreign.create(
      budgetId: budgetId,
      identity: const PublicIdentity(
        userId: 'intruder',
        deviceId: 'intruder-device',
        publicKey: 'ed25519:intruder',
      ),
    );

    await expectLater(
      trusted.verify(expectedBudgetId: budgetId, hello: hello),
      throwsA(
        isA<LanSessionError>().having(
          (error) => error.code,
          'code',
          LanSessionErrorCode.invalidSecretProof,
        ),
      ),
    );
  });
}

Future<BudgetTransportSecretManager> _manager(String secret) async {
  final store = _MemorySecretStore();
  await store.save(budgetId: 'budget-1', secret: secret);
  return BudgetTransportSecretManager(
    store: store,
    tokenGenerator: const _FixedTokenGenerator('unused'),
  );
}

LanHandshakeService _handshake({
  required BudgetTransportSecretManager manager,
  required String nonce,
}) {
  return LanHandshakeService(
    transportSecretManager: manager,
    signatureService: const _SignatureService(),
    tokenGenerator: _FixedTokenGenerator(nonce),
  );
}

LanSecureSessionService _sessionService({
  required BudgetTransportSecretManager manager,
  required String nonce,
}) {
  return LanSecureSessionService(
    handshakeService: _handshake(manager: manager, nonce: nonce),
    sessionCrypto: LanSessionCrypto(),
    transportSecretManager: manager,
  );
}

final class _MemorySecretStore implements BudgetTransportSecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> load(String budgetId) async => _values[budgetId];

  @override
  Future<void> save({required String budgetId, required String secret}) async {
    _values[budgetId] = secret;
  }

  @override
  Future<void> delete(String budgetId) async {
    _values.remove(budgetId);
  }
}

final class _FixedTokenGenerator implements SecureTokenGenerator {
  const _FixedTokenGenerator(this.value);

  final String value;

  @override
  String nextToken({int bytes = 32}) => value;
}

final class _SignatureService implements IdentitySignatureService {
  const _SignatureService();

  @override
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  }) async {
    return base64Url.encode(message);
  }

  @override
  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  }) async {
    return signature == base64Url.encode(message);
  }
}

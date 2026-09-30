import 'dart:convert';

import 'package:budget_accounting_system/src/application/ports/lan_discovery_gateway.dart';
import 'package:budget_accounting_system/src/application/ports/lan_local_address_resolver.dart';
import 'package:budget_accounting_system/src/application/services/budget_transport_secret_manager.dart';
import 'package:budget_accounting_system/src/application/services/lan_discovery_token_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_handshake_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_peer_session_manager.dart';
import 'package:budget_accounting_system/src/application/services/lan_secure_session_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_session_crypto.dart';
import 'package:budget_accounting_system/src/application/use_cases/ensure_local_identity.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_public_identity.dart';
import 'package:budget_accounting_system/src/data/network/tcp_lan_transport_gateway.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/lan_peer_endpoint.dart';
import 'package:budget_accounting_system/src/domain/models/local_device.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/onboarding_fakes.dart';

void main() {
  const budgetId = 'budget-1';

  test('manual endpoint establishes encrypted session and reconnects', () async {
    final ownerSecrets = FakeBudgetTransportSecretStore()
      ..secretsByBudget[budgetId] = _secret;
    final memberSecrets = FakeBudgetTransportSecretStore()
      ..secretsByBudget[budgetId] = _secret;
    final discovery = _DiscoveryGateway();

    final owner = _manager(
      userId: 'owner-1',
      deviceId: 'owner-device',
      role: MemberRole.owner,
      secrets: ownerSecrets,
      discovery: discovery,
    );
    final member = _manager(
      userId: 'member-1',
      deviceId: 'member-device',
      role: MemberRole.editor,
      secrets: memberSecrets,
      discovery: discovery,
    );

    final hosted = await owner.host(budgetId);
    try {
      expect(hosted.manualEndpointCode, isNotNull);
      final endpoint = member.decodeManualEndpoint(hosted.manualEndpointCode!);

      Future<void> connectAndExchange(String payload) async {
        final incomingFuture = hosted.channels.first;
        final outgoing = await member.connect(
          budgetId: budgetId,
          endpoint: endpoint,
        );
        final incoming = await incomingFuture;

        try {
          await outgoing.send(utf8.encode(payload));
          expect(utf8.decode(await incoming.receive()), payload);
        } finally {
          await outgoing.close();
          await incoming.close();
        }
      }

      await connectAndExchange('first connection');
      await connectAndExchange('reconnected');
    } finally {
      await hosted.close();
    }
  });

  test('discovery derives private budget token and filters local device id', () async {
    final secrets = FakeBudgetTransportSecretStore()
      ..secretsByBudget[budgetId] = _secret;
    final discovery = _DiscoveryGateway();
    final manager = _manager(
      userId: 'user-1',
      deviceId: 'device-1',
      role: MemberRole.viewer,
      secrets: secrets,
      discovery: discovery,
    );

    final browser = await manager.discover(budgetId);
    try {
      expect(discovery.lastDiscoveryToken, isNotNull);
      expect(discovery.lastDiscoveryToken, isNot(contains(budgetId)));
      expect(discovery.lastLocalDeviceId, 'device-1');
    } finally {
      await browser.close();
    }
  });
}

const _secret = 'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=';

LanPeerSessionManager _manager({
  required String userId,
  required String deviceId,
  required MemberRole role,
  required FakeBudgetTransportSecretStore secrets,
  required _DiscoveryGateway discovery,
}) {
  final identities = FakeIdentityRepository(
    publicKeysByUser: {userId: 'ed25519:$userId'},
    devicesById: {
      deviceId: LocalDevice(
        id: deviceId,
        userId: userId,
        revokedAt: null,
      ),
    },
  );
  final keys = FakeIdentityKeyStore()
    ..deviceByUser[userId] = deviceId
    ..privateKeyByDevice[deviceId] = 'private-$userId';
  final getPublicIdentity = GetPublicIdentity(
    EnsureLocalIdentity(
      identityRepository: identities,
      keyStore: keys,
      keyPairGenerator: FakeIdentityKeyPairGenerator(
        publicKey: 'ed25519:$userId',
        privateKey: 'private-$userId',
      ),
      idGenerator: FakeIdGenerator(const []),
    ),
  );
  final tokens = FakeSecureTokenGenerator();
  final secretManager = BudgetTransportSecretManager(
    store: secrets,
    tokenGenerator: tokens,
  );
  final signatures = FakeIdentitySignatureService();
  final handshake = LanHandshakeService(
    transportSecretManager: secretManager,
    signatureService: signatures,
    tokenGenerator: tokens,
  );
  final secureSession = LanSecureSessionService(
    handshakeService: handshake,
    sessionCrypto: LanSessionCrypto(),
    transportSecretManager: secretManager,
  );

  return LanPeerSessionManager(
    authorization: FakeBudgetAuthorizationGuard(
      userId: userId,
      role: role,
    ),
    getPublicIdentity: getPublicIdentity,
    discovery: discovery,
    transport: const TcpLanTransportGateway(),
    secureSession: secureSession,
    discoveryTokenService: LanDiscoveryTokenService(
      transportSecretManager: secretManager,
    ),
    localAddressResolver: const _LoopbackResolver(),
  );
}

final class _LoopbackResolver implements LanLocalAddressResolver {
  const _LoopbackResolver();

  @override
  Future<String?> resolveIpv4() async => '127.0.0.1';
}

final class _DiscoveryGateway implements LanDiscoveryGateway {
  String? lastDiscoveryToken;
  String? lastLocalDeviceId;

  @override
  Future<LanAdvertisementHandle> advertise({
    required int port,
    required String discoveryToken,
    required String deviceId,
  }) async {
    return const _Advertisement();
  }

  @override
  Future<LanDiscoveryHandle> discover({
    required String discoveryToken,
    required String localDeviceId,
  }) async {
    lastDiscoveryToken = discoveryToken;
    lastLocalDeviceId = localDeviceId;
    return const _Discovery();
  }
}

final class _Advertisement implements LanAdvertisementHandle {
  const _Advertisement();

  @override
  Future<void> close() async {}
}

final class _Discovery implements LanDiscoveryHandle {
  const _Discovery();

  @override
  Stream<List<LanPeerEndpoint>> get peers =>
      const Stream<List<LanPeerEndpoint>>.empty();

  @override
  Future<void> close() async {}
}

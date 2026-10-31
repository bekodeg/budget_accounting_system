import 'dart:async';

import 'package:budget_accounting_system/src/application/ports/lan_discovery_gateway.dart';
import 'package:budget_accounting_system/src/application/ports/lan_local_address_resolver.dart';
import 'package:budget_accounting_system/src/application/ports/sync_journal.dart';
import 'package:budget_accounting_system/src/application/services/budget_transport_secret_manager.dart';
import 'package:budget_accounting_system/src/application/services/lan_discovery_token_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_handshake_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_peer_session_manager.dart';
import 'package:budget_accounting_system/src/application/services/lan_secure_session_service.dart';
import 'package:budget_accounting_system/src/application/services/lan_session_crypto.dart';
import 'package:budget_accounting_system/src/application/services/sync_session_service.dart';
import 'package:budget_accounting_system/src/application/use_cases/ensure_local_identity.dart';
import 'package:budget_accounting_system/src/application/use_cases/get_public_identity.dart';
import 'package:budget_accounting_system/src/data/network/tcp_lan_transport_gateway.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/lan_peer_endpoint.dart';
import 'package:budget_accounting_system/src/domain/models/local_device.dart';
import 'package:budget_accounting_system/src/domain/models/sync_protocol.dart';
import 'package:budget_accounting_system/src/presentation/screens/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('sync action starts discovery for active budget and can retry', (
    tester,
  ) async {
    const budgetId = 'budget-1';
    const userId = 'user-1';
    const deviceId = 'device-1';
    final discovery = _DiscoveryGateway();
    final secrets = FakeBudgetTransportSecretStore()
      ..secretsByBudget[budgetId] =
          'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=';
    final tokens = FakeSecureTokenGenerator();
    final secretManager = BudgetTransportSecretManager(
      store: secrets,
      tokenGenerator: tokens,
    );
    final identities = FakeIdentityRepository(
      publicKeysByUser: {userId: 'ed25519:$userId'},
      devicesById: {
        deviceId: LocalDevice(id: deviceId, userId: userId, revokedAt: null),
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
    final sessions = LanPeerSessionManager(
      authorization: FakeBudgetAuthorizationGuard(
        userId: userId,
        role: MemberRole.owner,
      ),
      getPublicIdentity: getPublicIdentity,
      discovery: discovery,
      transport: const TcpLanTransportGateway(),
      secureSession: LanSecureSessionService(
        handshakeService: LanHandshakeService(
          transportSecretManager: secretManager,
          signatureService: FakeIdentitySignatureService(),
          tokenGenerator: tokens,
        ),
        sessionCrypto: LanSessionCrypto(),
        transportSecretManager: secretManager,
      ),
      discoveryTokenService: LanDiscoveryTokenService(
        transportSecretManager: secretManager,
      ),
      transportSecretManager: secretManager,
      localAddressResolver: const _LocalAddressResolver(),
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
      lanPeerSessions: sessions,
      syncSessions: SyncSessionService(journal: _UnusedJournal()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          services: services,
          userId: userId,
          budgetId: budgetId,
          budgetName: 'Дом',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-synchronization')));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(discovery.calls, 1);
    expect(discovery.localDeviceId, deviceId);
    expect(discovery.discoveryToken, isNot(contains(budgetId)));
    expect(find.textContaining('Устройства пока не найдены'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync-manual-endpoint-input')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('sync-discover')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('sync-discover')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100 && discovery.calls < 2; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(discovery.calls, 2);
    expect(discovery.closedHandles, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(discovery.closedHandles, 2);
  });
}

final class _DiscoveryGateway implements LanDiscoveryGateway {
  int calls = 0;
  int closedHandles = 0;
  String? discoveryToken;
  String? localDeviceId;

  @override
  Future<LanDiscoveryHandle> discover({
    required String discoveryToken,
    required String localDeviceId,
  }) async {
    calls++;
    this.discoveryToken = discoveryToken;
    this.localDeviceId = localDeviceId;
    return _DiscoveryHandle(() => closedHandles++);
  }

  @override
  Future<LanAdvertisementHandle> advertise({
    required int port,
    required String discoveryToken,
    required String deviceId,
  }) => throw UnimplementedError();
}

final class _DiscoveryHandle implements LanDiscoveryHandle {
  _DiscoveryHandle(this.onClose);

  final void Function() onClose;
  final _controller = StreamController<List<LanPeerEndpoint>>.broadcast();

  @override
  Stream<List<LanPeerEndpoint>> get peers => _controller.stream;

  @override
  Future<void> close() async {
    onClose();
    await _controller.close();
  }
}

final class _LocalAddressResolver implements LanLocalAddressResolver {
  const _LocalAddressResolver();

  @override
  Future<String?> resolveIpv4() async => '127.0.0.1';
}

final class _UnusedJournal implements SyncJournal {
  @override
  Future<SyncStateVector> stateVector(String budgetId) =>
      throw UnimplementedError();

  @override
  Future<SyncOperationPage> missingOperations({
    required String budgetId,
    required SyncStateVector remoteState,
    required int limit,
  }) => throw UnimplementedError();

  @override
  Future<SyncIngestResult> ingest({
    required String budgetId,
    required List<SyncWireOperation> operations,
  }) => throw UnimplementedError();
}

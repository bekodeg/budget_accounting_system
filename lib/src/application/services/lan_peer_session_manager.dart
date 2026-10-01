import 'dart:async';

import '../../domain/models/lan_peer_endpoint.dart';
import '../../domain/models/public_identity.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../ports/lan_discovery_gateway.dart';
import '../ports/lan_local_address_resolver.dart';
import '../ports/lan_transport_gateway.dart';
import '../ports/secure_lan_channel.dart';
import '../use_cases/get_public_identity.dart';
import 'lan_discovery_token_service.dart';
import 'lan_endpoint_codec.dart';
import 'lan_secure_session_service.dart';

final class LanPeerBrowser {
  const LanPeerBrowser(this._handle);

  final LanDiscoveryHandle _handle;

  Stream<List<LanPeerEndpoint>> get peers => _handle.peers;

  Future<void> close() => _handle.close();
}

final class LanHostedSession {
  LanHostedSession({
    required this.port,
    required this.manualEndpointCode,
    required this.channels,
    required Future<void> Function() close,
  }) : _close = close;

  final int port;
  final String? manualEndpointCode;
  final Stream<SecureLanChannel> channels;
  final Future<void> Function() _close;

  Future<void> close() => _close();
}

final class LanPeerSessionManager {
  const LanPeerSessionManager({
    required BudgetAuthorizationGuard authorization,
    required GetPublicIdentity getPublicIdentity,
    required LanDiscoveryGateway discovery,
    required LanTransportGateway transport,
    required LanSecureSessionService secureSession,
    required LanDiscoveryTokenService discoveryTokenService,
    required LanLocalAddressResolver localAddressResolver,
    LanEndpointCodec endpointCodec = const LanEndpointCodec(),
  }) : _authorization = authorization,
       _getPublicIdentity = getPublicIdentity,
       _discovery = discovery,
       _transport = transport,
       _secureSession = secureSession,
       _discoveryTokenService = discoveryTokenService,
       _localAddressResolver = localAddressResolver,
       _endpointCodec = endpointCodec;

  final BudgetAuthorizationGuard _authorization;
  final GetPublicIdentity _getPublicIdentity;
  final LanDiscoveryGateway _discovery;
  final LanTransportGateway _transport;
  final LanSecureSessionService _secureSession;
  final LanDiscoveryTokenService _discoveryTokenService;
  final LanLocalAddressResolver _localAddressResolver;
  final LanEndpointCodec _endpointCodec;

  Future<LanPeerBrowser> discover(String budgetId) async {
    final identity = await _identityFor(budgetId);
    final token = await _discoveryTokenService.forBudget(budgetId);
    final handle = await _discovery.discover(
      discoveryToken: token,
      localDeviceId: identity.deviceId,
    );
    return LanPeerBrowser(handle);
  }

  Future<LanHostedSession> host(String budgetId) async {
    final identity = await _identityFor(budgetId);
    final token = await _discoveryTokenService.forBudget(budgetId);
    final listener = await _transport.listen();

    LanAdvertisementHandle advertisement;
    try {
      advertisement = await _discovery.advertise(
        port: listener.port,
        discoveryToken: token,
        deviceId: identity.deviceId,
      );
    } on Object {
      await listener.close();
      rethrow;
    }

    final controller = StreamController<SecureLanChannel>.broadcast();
    late final StreamSubscription<LanByteChannel> subscription;
    var closed = false;

    subscription = listener.connections.listen((rawChannel) {
      unawaited(
        _acceptIncoming(
          rawChannel: rawChannel,
          budgetId: budgetId,
          identityUserId: identity.userId,
          controller: controller,
        ),
      );
    }, onError: controller.addError);

    final hostAddress = await _localAddressResolver.resolveIpv4();
    final manualEndpointCode = hostAddress == null
        ? null
        : _endpointCodec.encode(
            LanPeerEndpoint(
              serviceName: 'Budget-${_deviceHint(identity.deviceId)}',
              host: hostAddress,
              port: listener.port,
              deviceHint: _deviceHint(identity.deviceId),
            ),
          );

    return LanHostedSession(
      port: listener.port,
      manualEndpointCode: manualEndpointCode,
      channels: controller.stream,
      close: () async {
        if (closed) return;
        closed = true;
        await subscription.cancel();
        await advertisement.close();
        await listener.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );
  }

  Future<SecureLanChannel> connect({
    required String budgetId,
    required LanPeerEndpoint endpoint,
  }) async {
    final identity = await _identityFor(budgetId);
    final raw = await _transport.connect(
      host: endpoint.host,
      port: endpoint.port,
    );
    try {
      return await _secureSession.initiate(
        channel: raw,
        budgetId: budgetId,
        identity: identity,
      );
    } on Object {
      await raw.close();
      rethrow;
    }
  }

  LanPeerEndpoint decodeManualEndpoint(String value) {
    return _endpointCodec.decode(value);
  }

  Future<PublicIdentity> _identityFor(String budgetId) async {
    final member = await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.read,
    );
    return _getPublicIdentity(member.userId);
  }

  Future<void> _acceptIncoming({
    required LanByteChannel rawChannel,
    required String budgetId,
    required String identityUserId,
    required StreamController<SecureLanChannel> controller,
  }) async {
    try {
      final identity = await _getPublicIdentity(identityUserId);
      final secured = await _secureSession.accept(
        channel: rawChannel,
        budgetId: budgetId,
        identity: identity,
      );
      if (controller.isClosed) {
        await secured.close();
        return;
      }
      controller.add(secured);
    } on Object {
      await rawChannel.close();
    }
  }
}

String _deviceHint(String deviceId) {
  final normalized = deviceId.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (normalized.isEmpty) return 'device';
  final length = normalized.length > 8 ? 8 : normalized.length;
  return normalized.substring(0, length);
}

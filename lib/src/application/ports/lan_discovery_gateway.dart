import '../../domain/models/lan_peer_endpoint.dart';

abstract interface class LanDiscoveryHandle {
  Stream<List<LanPeerEndpoint>> get peers;

  Future<void> close();
}

abstract interface class LanAdvertisementHandle {
  Future<void> close();
}

abstract interface class LanDiscoveryGateway {
  Future<LanDiscoveryHandle> discover({
    required String discoveryToken,
    required String localDeviceId,
  });

  Future<LanAdvertisementHandle> advertise({
    required int port,
    required String discoveryToken,
    required String deviceId,
  });
}

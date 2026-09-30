import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import '../../application/ports/lan_discovery_gateway.dart';
import '../../domain/models/lan_peer_endpoint.dart';

final class NsdLanDiscoveryGateway implements LanDiscoveryGateway {
  const NsdLanDiscoveryGateway();

  static const serviceType = '_budgetsync._tcp';

  @override
  Future<LanAdvertisementHandle> advertise({
    required int port,
    required String discoveryToken,
    required String deviceId,
  }) async {
    final registration = await nsd.register(
      nsd.Service(
        name: _serviceName(deviceId),
        type: serviceType,
        port: port,
        txt: {
          'v': Uint8List.fromList(utf8.encode('1')),
          't': Uint8List.fromList(utf8.encode(discoveryToken)),
          'd': Uint8List.fromList(utf8.encode(_deviceHint(deviceId))),
        },
      ),
    );
    return _NsdAdvertisement(registration);
  }

  @override
  Future<LanDiscoveryHandle> discover({
    required String discoveryToken,
    required String localDeviceId,
  }) async {
    final controller =
        StreamController<List<LanPeerEndpoint>>.broadcast(sync: true);
    final peers = <String, LanPeerEndpoint>{};
    final discovery = await nsd.startDiscovery(serviceType);

    void emit() {
      final values = peers.values.toList(growable: false)
        ..sort((a, b) => a.serviceName.compareTo(b.serviceName));
      if (!controller.isClosed) controller.add(values);
    }

    discovery.addServiceListener((service, status) {
      final name = service.name;
      if (name == null) return;
      final key = '$name|${service.host}|${service.port}';

      if (status == nsd.ServiceStatus.lost) {
        peers.remove(key);
        emit();
        return;
      }
      if (status != nsd.ServiceStatus.found) return;

      final txt = service.txt;
      final token = _readTxt(txt?['t']);
      final deviceHint = _readTxt(txt?['d']);
      final host = service.host;
      final port = service.port;
      if (token != discoveryToken ||
          deviceHint == _deviceHint(localDeviceId) ||
          host == null ||
          port == null) {
        return;
      }

      peers[key] = LanPeerEndpoint(
        serviceName: name,
        host: host,
        port: port,
        deviceHint: deviceHint ?? '',
      );
      emit();
    });

    emit();
    return _NsdDiscovery(
      discovery: discovery,
      controller: controller,
    );
  }
}

final class _NsdDiscovery implements LanDiscoveryHandle {
  _NsdDiscovery({
    required nsd.Discovery discovery,
    required StreamController<List<LanPeerEndpoint>> controller,
  }) : _discovery = discovery,
       _controller = controller;

  final nsd.Discovery _discovery;
  final StreamController<List<LanPeerEndpoint>> _controller;
  var _closed = false;

  @override
  Stream<List<LanPeerEndpoint>> get peers => _controller.stream;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await nsd.stopDiscovery(_discovery);
    await _controller.close();
  }
}

final class _NsdAdvertisement implements LanAdvertisementHandle {
  _NsdAdvertisement(this._registration);

  final nsd.Registration _registration;
  var _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await nsd.unregister(_registration);
  }
}

String? _readTxt(Uint8List? value) =>
    value == null ? null : utf8.decode(value, allowMalformed: false);

String _serviceName(String deviceId) =>
    'Budget-${_deviceHint(deviceId)}';

String _deviceHint(String deviceId) {
  final normalized = deviceId.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (normalized.isEmpty) return 'device';
  final length = normalized.length > 8 ? 8 : normalized.length;
  return normalized.substring(0, length);
}

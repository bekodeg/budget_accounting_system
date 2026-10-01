import 'dart:convert';

import '../../domain/models/lan_peer_endpoint.dart';

final class LanEndpointCodec {
  const LanEndpointCodec();

  static const _prefix = 'budgetlan:';

  String encode(LanPeerEndpoint endpoint) {
    final payload = jsonEncode({
      'v': 1,
      'name': endpoint.serviceName,
      'host': endpoint.host,
      'port': endpoint.port,
      'device': endpoint.deviceHint,
    });
    return _prefix + base64Url.encode(utf8.encode(payload));
  }

  LanPeerEndpoint decode(String value) {
    if (!value.startsWith(_prefix)) {
      throw const FormatException('Invalid LAN endpoint code.');
    }

    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(value.substring(_prefix.length))),
    );
    if (decoded is! Map<String, dynamic> || decoded['v'] != 1) {
      throw const FormatException('Unsupported LAN endpoint code.');
    }

    final name = decoded['name'];
    final host = decoded['host'];
    final port = decoded['port'];
    final device = decoded['device'];
    if (name is! String ||
        name.isEmpty ||
        host is! String ||
        host.isEmpty ||
        port is! int ||
        port <= 0 ||
        port > 65535 ||
        device is! String) {
      throw const FormatException('Invalid LAN endpoint fields.');
    }

    return LanPeerEndpoint(
      serviceName: name,
      host: host,
      port: port,
      deviceHint: device,
    );
  }
}

final class LanPeerEndpoint {
  const LanPeerEndpoint({
    required this.serviceName,
    required this.host,
    required this.port,
    required this.deviceHint,
  });

  final String serviceName;
  final String host;
  final int port;
  final String deviceHint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanPeerEndpoint &&
          other.serviceName == serviceName &&
          other.host == host &&
          other.port == port &&
          other.deviceHint == deviceHint;

  @override
  int get hashCode => Object.hash(serviceName, host, port, deviceHint);
}

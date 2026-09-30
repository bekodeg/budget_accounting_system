abstract interface class LanByteChannel {
  Stream<List<int>> get frames;

  Future<void> send(List<int> frame);

  Future<void> close();
}

abstract interface class LanListener {
  int get port;

  Stream<LanByteChannel> get connections;

  Future<void> close();
}

abstract interface class LanTransportGateway {
  Future<LanListener> listen();

  Future<LanByteChannel> connect({
    required String host,
    required int port,
  });
}

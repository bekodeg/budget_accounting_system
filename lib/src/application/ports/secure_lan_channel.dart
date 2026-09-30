import '../../domain/models/lan_session.dart';

abstract interface class SecureLanChannel {
  LanPeerDescriptor get remotePeer;

  Future<List<int>> receive();

  Future<void> send(List<int> clearText);

  Future<void> close();
}

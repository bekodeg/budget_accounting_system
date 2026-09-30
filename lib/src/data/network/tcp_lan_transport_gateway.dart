import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/lan_transport_gateway.dart';

final class TcpLanTransportGateway implements LanTransportGateway {
  const TcpLanTransportGateway();

  @override
  Future<LanByteChannel> connect({
    required String host,
    required int port,
  }) async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 8),
    );
    return _SocketLanChannel(socket);
  }

  @override
  Future<LanListener> listen() async {
    final server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    return _SocketLanListener(server);
  }
}

final class _SocketLanListener implements LanListener {
  _SocketLanListener(this._server) {
    _subscription = _server.listen(
      (socket) => _connections.add(_SocketLanChannel(socket)),
      onError: _connections.addError,
      onDone: _connections.close,
    );
  }

  final ServerSocket _server;
  final StreamController<LanByteChannel> _connections =
      StreamController<LanByteChannel>.broadcast();
  late final StreamSubscription<Socket> _subscription;
  var _closed = false;

  @override
  int get port => _server.port;

  @override
  Stream<LanByteChannel> get connections => _connections.stream;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await _server.close();
    if (!_connections.isClosed) await _connections.close();
  }
}

final class _SocketLanChannel implements LanByteChannel {
  _SocketLanChannel(this._socket) {
    _subscription = _socket.listen(
      _onData,
      onError: _frames.addError,
      onDone: _frames.close,
      cancelOnError: false,
    );
  }

  static const _headerLength = 4;
  static const _maxFrameLength = 16 * 1024 * 1024;

  final Socket _socket;
  final StreamController<List<int>> _frames =
      StreamController<List<int>>.broadcast();
  late final StreamSubscription<Uint8List> _subscription;
  final List<int> _buffer = [];
  var _closed = false;

  @override
  Stream<List<int>> get frames => _frames.stream;

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    while (_buffer.length >= _headerLength) {
      final length =
          (_buffer[0] << 24) |
          (_buffer[1] << 16) |
          (_buffer[2] << 8) |
          _buffer[3];
      if (length < 0 || length > _maxFrameLength) {
        _frames.addError(
          StateError('Invalid LAN frame length: $length'),
        );
        unawaited(close());
        return;
      }
      if (_buffer.length < _headerLength + length) return;

      final frame = List<int>.unmodifiable(
        _buffer.sublist(_headerLength, _headerLength + length),
      );
      _buffer.removeRange(0, _headerLength + length);
      _frames.add(frame);
    }
  }

  @override
  Future<void> send(List<int> frame) async {
    if (_closed) throw StateError('LAN channel is closed.');
    if (frame.length > _maxFrameLength) {
      throw ArgumentError.value(frame.length, 'frame', 'Frame is too large.');
    }

    final header = ByteData(_headerLength)..setUint32(0, frame.length);
    _socket.add(header.buffer.asUint8List());
    _socket.add(frame);
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await _socket.close();
    if (!_frames.isClosed) await _frames.close();
  }
}

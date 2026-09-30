import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/lan_peer_hello.dart';
import '../../domain/models/lan_session.dart';
import '../../domain/models/public_identity.dart';
import '../ports/lan_transport_gateway.dart';
import '../ports/secure_lan_channel.dart';
import 'lan_handshake_service.dart';
import 'lan_peer_hello_codec.dart';
import 'lan_session_crypto.dart';

final class LanSecureSessionService {
  const LanSecureSessionService({
    required LanHandshakeService handshakeService,
    required LanSessionCrypto sessionCrypto,
    LanPeerHelloCodec helloCodec = const LanPeerHelloCodec(),
  }) : _handshakeService = handshakeService,
       _sessionCrypto = sessionCrypto,
       _helloCodec = helloCodec;

  final LanHandshakeService _handshakeService;
  final LanSessionCrypto _sessionCrypto;
  final LanPeerHelloCodec _helloCodec;

  Future<SecureLanChannel> initiate({
    required LanByteChannel channel,
    required String budgetId,
    required PublicIdentity identity,
  }) async {
    final localHello = await _handshakeService.create(
      budgetId: budgetId,
      identity: identity,
    );
    await channel.send(_helloCodec.encode(localHello));

    final remoteHello = _helloCodec.decode(
      await channel.receive().timeout(const Duration(seconds: 8)),
    );
    await _handshakeService.verify(
      expectedBudgetId: budgetId,
      hello: remoteHello,
    );

    return _secure(
      channel: channel,
      budgetId: budgetId,
      localHello: localHello,
      remoteHello: remoteHello,
    );
  }

  Future<SecureLanChannel> accept({
    required LanByteChannel channel,
    required String budgetId,
    required PublicIdentity identity,
  }) async {
    final remoteHello = _helloCodec.decode(
      await channel.receive().timeout(const Duration(seconds: 8)),
    );
    await _handshakeService.verify(
      expectedBudgetId: budgetId,
      hello: remoteHello,
    );

    final localHello = await _handshakeService.create(
      budgetId: budgetId,
      identity: identity,
    );
    await channel.send(_helloCodec.encode(localHello));

    return _secure(
      channel: channel,
      budgetId: budgetId,
      localHello: localHello,
      remoteHello: remoteHello,
    );
  }

  Future<SecureLanChannel> _secure({
    required LanByteChannel channel,
    required String budgetId,
    required LanPeerHello localHello,
    required LanPeerHello remoteHello,
  }) async {
    final secret = await _handshakeService.transportSecretFor(budgetId);
    final sessionKey = await _sessionCrypto.deriveSessionKey(
      budgetSecret: secret,
      local: localHello.peer,
      remote: remoteHello.peer,
    );

    return _EncryptedLanChannel(
      channel: channel,
      sessionKey: sessionKey,
      budgetId: budgetId,
      remotePeer: remoteHello.peer,
      crypto: _sessionCrypto,
    );
  }
}

final class _EncryptedLanChannel implements SecureLanChannel {
  const _EncryptedLanChannel({
    required LanByteChannel channel,
    required SecretKey sessionKey,
    required String budgetId,
    required LanPeerDescriptor remotePeer,
    required LanSessionCrypto crypto,
  }) : _channel = channel,
       _sessionKey = sessionKey,
       _budgetId = budgetId,
       _remotePeer = remotePeer,
       _crypto = crypto;

  final LanByteChannel _channel;
  final SecretKey _sessionKey;
  final String _budgetId;
  final LanPeerDescriptor _remotePeer;
  final LanSessionCrypto _crypto;

  @override
  LanPeerDescriptor get remotePeer => _remotePeer;

  @override
  Future<void> send(List<int> clearText) async {
    final encrypted = await _crypto.encrypt(
      clearText: clearText,
      sessionKey: _sessionKey,
      budgetId: _budgetId,
    );
    await _channel.send(
      utf8.encode(
        jsonEncode({
          'nonce': base64Url.encode(encrypted.nonce),
          'cipher': base64Url.encode(encrypted.cipherText),
          'mac': base64Url.encode(encrypted.mac),
        }),
      ),
    );
  }

  @override
  Future<List<int>> receive() async {
    final raw = jsonDecode(utf8.decode(await _channel.receive()));
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted LAN frame.');
    }

    final nonce = raw['nonce'];
    final cipher = raw['cipher'];
    final mac = raw['mac'];
    if (nonce is! String || cipher is! String || mac is! String) {
      throw const FormatException('Invalid encrypted LAN frame fields.');
    }

    return _crypto.decrypt(
      frame: EncryptedLanFrame(
        nonce: base64Url.decode(nonce),
        cipherText: base64Url.decode(cipher),
        mac: base64Url.decode(mac),
      ),
      sessionKey: _sessionKey,
      budgetId: _budgetId,
    );
  }

  @override
  Future<void> close() => _channel.close();
}

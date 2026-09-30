import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/lan_peer_hello.dart';
import '../../domain/models/lan_session.dart';
import '../errors/lan_session_error.dart';

final class LanPeerHelloCodec {
  const LanPeerHelloCodec();

  Uint8List descriptorBytes(LanPeerDescriptor peer) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'budget_id': peer.budgetId,
          'user_id': peer.userId,
          'device_id': peer.deviceId,
          'public_key': peer.publicKey,
          'nonce': peer.nonce,
        }),
      ),
    );
  }

  Uint8List signatureBytes({
    required LanPeerDescriptor peer,
    required String secretProof,
  }) {
    return Uint8List.fromList([
      ...descriptorBytes(peer),
      ...utf8.encode('|proof|$secretProof'),
    ]);
  }

  List<int> encode(LanPeerHello hello) {
    return utf8.encode(
      jsonEncode({
        'v': hello.version,
        'peer': {
          'budget_id': hello.peer.budgetId,
          'user_id': hello.peer.userId,
          'device_id': hello.peer.deviceId,
          'public_key': hello.peer.publicKey,
          'nonce': hello.peer.nonce,
        },
        'secret_proof': hello.secretProof,
        'identity_signature': hello.identitySignature,
      }),
    );
  }

  LanPeerHello decode(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic> ||
          value['v'] != LanPeerHello.currentVersion) {
        throw const LanSessionError(
          LanSessionErrorCode.invalidHandshake,
          'Unsupported LAN handshake version.',
        );
      }
      final peer = value['peer'];
      if (peer is! Map<String, dynamic>) {
        throw const LanSessionError(
          LanSessionErrorCode.invalidHandshake,
          'LAN handshake peer descriptor is missing.',
        );
      }

      return LanPeerHello(
        version: LanPeerHello.currentVersion,
        peer: LanPeerDescriptor(
          budgetId: _requiredString(peer, 'budget_id'),
          userId: _requiredString(peer, 'user_id'),
          deviceId: _requiredString(peer, 'device_id'),
          publicKey: _requiredString(peer, 'public_key'),
          nonce: _requiredString(peer, 'nonce'),
        ),
        secretProof: _requiredString(value, 'secret_proof'),
        identitySignature: _requiredString(value, 'identity_signature'),
      );
    } on LanSessionError {
      rethrow;
    } on Object {
      throw const LanSessionError(
        LanSessionErrorCode.invalidHandshake,
        'Unable to decode LAN handshake.',
      );
    }
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw const LanSessionError(
      LanSessionErrorCode.invalidHandshake,
      'LAN handshake contains an invalid required field.',
    );
  }
  return value;
}

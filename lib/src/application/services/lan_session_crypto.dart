import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/lan_session.dart';

final class LanSessionCrypto {
  LanSessionCrypto({Hkdf? hkdf, Chacha20? cipher})
    : _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
      _cipher = cipher ?? Chacha20.poly1305Aead();

  final Hkdf _hkdf;
  final Chacha20 _cipher;

  Future<SecretKey> deriveSessionKey({
    required String budgetSecret,
    required LanPeerDescriptor local,
    required LanPeerDescriptor remote,
  }) async {
    if (local.budgetId != remote.budgetId) {
      throw ArgumentError('Peers must belong to the same budget.');
    }

    final orderedNonces = [local.nonce, remote.nonce]..sort();
    final orderedDevices = [local.deviceId, remote.deviceId]..sort();
    final nonce = utf8.encode(orderedNonces.join('|'));
    final info = utf8.encode(
      'budget-lan-v1|${local.budgetId}|${orderedDevices.join('|')}',
    );

    return _hkdf.deriveKey(
      secretKey: SecretKey(base64Url.decode(budgetSecret)),
      nonce: nonce,
      info: info,
    );
  }

  Future<EncryptedLanFrame> encrypt({
    required List<int> clearText,
    required SecretKey sessionKey,
    required String budgetId,
  }) async {
    final box = await _cipher.encrypt(
      clearText,
      secretKey: sessionKey,
      aad: utf8.encode('budget-lan-v1|$budgetId'),
    );
    return EncryptedLanFrame(
      nonce: Uint8List.fromList(box.nonce),
      cipherText: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  Future<List<int>> decrypt({
    required EncryptedLanFrame frame,
    required SecretKey sessionKey,
    required String budgetId,
  }) {
    return _cipher.decrypt(
      SecretBox(frame.cipherText, nonce: frame.nonce, mac: Mac(frame.mac)),
      secretKey: sessionKey,
      aad: utf8.encode('budget-lan-v1|$budgetId'),
    );
  }
}

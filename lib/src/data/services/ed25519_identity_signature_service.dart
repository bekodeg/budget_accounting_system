import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../application/errors/invite_error.dart';
import '../../application/ports/identity_key_store.dart';
import '../../application/ports/identity_signature_service.dart';

final class Ed25519IdentitySignatureService
    implements IdentitySignatureService {
  Ed25519IdentitySignatureService({
    required IdentityKeyStore keyStore,
    Ed25519? algorithm,
  }) : _keyStore = keyStore,
       _algorithm = algorithm ?? Ed25519();

  final IdentityKeyStore _keyStore;
  final Ed25519 _algorithm;

  @override
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  }) async {
    final encodedSeed = await _keyStore.loadPrivateKey(deviceId);
    if (encodedSeed == null || encodedSeed.isEmpty) {
      throw const InviteError(
        InviteErrorCode.privateKeyUnavailable,
        'Private key владельца недоступен.',
      );
    }

    final keyPair = await _algorithm.newKeyPairFromSeed(
      base64Url.decode(encodedSeed),
    );
    try {
      final signature = await _algorithm.sign(message, keyPair: keyPair);
      return base64Url.encode(signature.bytes);
    } finally {
      keyPair.destroy();
    }
  }

  @override
  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  }) async {
    if (!publicKey.startsWith('ed25519:')) return false;

    try {
      final publicBytes = base64Url.decode(
        publicKey.substring('ed25519:'.length),
      );
      final public = SimplePublicKey(
        publicBytes,
        type: KeyPairType.ed25519,
      );
      return _algorithm.verify(
        message,
        signature: Signature(
          base64Url.decode(signature),
          publicKey: public,
        ),
      );
    } on Object {
      return false;
    }
  }
}

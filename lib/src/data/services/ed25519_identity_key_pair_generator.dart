import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../application/ports/identity_key_pair_generator.dart';

final class Ed25519IdentityKeyPairGenerator
    implements IdentityKeyPairGenerator {
  Ed25519IdentityKeyPairGenerator({Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  final Ed25519 _algorithm;

  @override
  Future<GeneratedIdentityKeyPair> generate() async {
    final keyPair = await _algorithm.newKeyPair();
    try {
      final privateKey = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      return GeneratedIdentityKeyPair(
        publicKey: _encodePublicKey(publicKey.bytes),
        privateKey: base64Url.encode(privateKey),
      );
    } finally {
      keyPair.destroy();
    }
  }

  @override
  Future<String> publicKeyFromPrivate(String privateKey) async {
    final seed = base64Url.decode(privateKey);
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    try {
      final publicKey = await keyPair.extractPublicKey();
      return _encodePublicKey(publicKey.bytes);
    } finally {
      keyPair.destroy();
    }
  }
}

String _encodePublicKey(List<int> bytes) =>
    'ed25519:${base64Url.encode(bytes)}';

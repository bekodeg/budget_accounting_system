import 'dart:typed_data';

abstract interface class IdentitySignatureService {
  Future<String> sign({
    required String deviceId,
    required Uint8List message,
  });

  Future<bool> verify({
    required String publicKey,
    required Uint8List message,
    required String signature,
  });
}

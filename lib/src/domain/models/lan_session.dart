import 'dart:typed_data';

final class LanPeerDescriptor {
  const LanPeerDescriptor({
    required this.budgetId,
    required this.userId,
    required this.deviceId,
    required this.publicKey,
    required this.nonce,
  });

  final String budgetId;
  final String userId;
  final String deviceId;
  final String publicKey;
  final String nonce;
}

final class EncryptedLanFrame {
  const EncryptedLanFrame({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
}

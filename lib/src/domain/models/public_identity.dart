final class PublicIdentity {
  const PublicIdentity({
    required this.userId,
    required this.deviceId,
    required this.publicKey,
  });

  final String userId;
  final String deviceId;
  final String publicKey;

  static const algorithm = 'ed25519';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicIdentity &&
          other.userId == userId &&
          other.deviceId == deviceId &&
          other.publicKey == publicKey;

  @override
  int get hashCode => Object.hash(userId, deviceId, publicKey);
}

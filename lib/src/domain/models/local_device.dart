final class LocalDevice {
  const LocalDevice({
    required this.id,
    required this.userId,
    required this.revokedAt,
  });

  final String id;
  final String userId;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}

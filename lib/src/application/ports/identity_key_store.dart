abstract interface class IdentityKeyStore {
  Future<String?> loadCurrentDeviceId(String userId);

  Future<String?> loadPrivateKey(String deviceId);

  Future<void> saveIdentity({
    required String userId,
    required String deviceId,
    required String privateKey,
  });

  Future<void> deleteIdentity({
    required String userId,
    required String deviceId,
  });
}

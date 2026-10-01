import '../models/local_device.dart';

abstract interface class IdentityRepository {
  Future<String?> getUserPublicKey(String userId);

  Future<LocalDevice?> findDevice(String deviceId);

  Future<void> migrateLegacyIdentity({
    required String userId,
    required String publicKey,
    required String deviceId,
  });
}

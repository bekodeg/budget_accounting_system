import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/ports/identity_key_store.dart';

final class FlutterSecureIdentityKeyStore implements IdentityKeyStore {
  FlutterSecureIdentityKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _deviceKey(String userId) => 'identity.user.$userId.device';

  static String _privateKey(String deviceId) =>
      'identity.device.$deviceId.ed25519.private';

  @override
  Future<String?> loadCurrentDeviceId(String userId) {
    return _storage.read(key: _deviceKey(userId));
  }

  @override
  Future<String?> loadPrivateKey(String deviceId) {
    return _storage.read(key: _privateKey(deviceId));
  }

  @override
  Future<void> saveIdentity({
    required String userId,
    required String deviceId,
    required String privateKey,
  }) async {
    await _storage.write(key: _privateKey(deviceId), value: privateKey);
    try {
      await _storage.write(key: _deviceKey(userId), value: deviceId);
    } on Object {
      await _storage.delete(key: _privateKey(deviceId));
      rethrow;
    }
  }

  @override
  Future<void> deleteIdentity({
    required String userId,
    required String deviceId,
  }) async {
    await _storage.delete(key: _privateKey(deviceId));
    final currentDeviceId = await loadCurrentDeviceId(userId);
    if (currentDeviceId == deviceId) {
      await _storage.delete(key: _deviceKey(userId));
    }
  }
}

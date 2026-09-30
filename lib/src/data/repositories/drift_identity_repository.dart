import '../../domain/models/local_device.dart';
import '../../domain/repositories/identity_repository.dart';
import '../dal/user_budget_dao.dart';

final class DriftIdentityRepository implements IdentityRepository {
  const DriftIdentityRepository(this._dao);

  final UserBudgetDao _dao;

  @override
  Future<String?> getUserPublicKey(String userId) async {
    final user = await _dao.findUserById(userId);
    return user?.publicKey;
  }

  @override
  Future<LocalDevice?> findDevice(String deviceId) async {
    final device = await _dao.findDeviceById(deviceId);
    if (device == null) return null;
    return LocalDevice(
      id: device.id,
      userId: device.userId,
      revokedAt: device.revokedAt,
    );
  }

  @override
  Future<void> migrateLegacyIdentity({
    required String userId,
    required String publicKey,
    required String deviceId,
  }) {
    return _dao.migrateLegacyIdentity(
      userId: userId,
      publicKey: publicKey,
      deviceId: deviceId,
    );
  }
}

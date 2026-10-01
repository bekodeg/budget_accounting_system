import '../../domain/models/public_identity.dart';
import '../../domain/repositories/identity_repository.dart';
import '../errors/identity_error.dart';
import '../ports/id_generator.dart';
import '../ports/identity_key_pair_generator.dart';
import '../ports/identity_key_store.dart';

final class EnsureLocalIdentity {
  const EnsureLocalIdentity({
    required IdentityRepository identityRepository,
    required IdentityKeyStore keyStore,
    required IdentityKeyPairGenerator keyPairGenerator,
    required IdGenerator idGenerator,
  }) : _identityRepository = identityRepository,
       _keyStore = keyStore,
       _keyPairGenerator = keyPairGenerator,
       _idGenerator = idGenerator;

  final IdentityRepository _identityRepository;
  final IdentityKeyStore _keyStore;
  final IdentityKeyPairGenerator _keyPairGenerator;
  final IdGenerator _idGenerator;

  Future<PublicIdentity> call(String userId) async {
    final storedPublicKey = await _identityRepository.getUserPublicKey(userId);
    if (storedPublicKey == null) {
      throw StateError('Identity user not found: $userId');
    }

    final currentDeviceId = await _keyStore.loadCurrentDeviceId(userId);
    if (currentDeviceId != null) {
      final device = await _identityRepository.findDevice(currentDeviceId);
      if (device?.isRevoked ?? false) {
        throw const IdentityError(
          IdentityErrorCode.revokedDevice,
          'Текущее устройство отозвано.',
        );
      }

      final privateKey = await _keyStore.loadPrivateKey(currentDeviceId);
      if (device != null &&
          device.userId == userId &&
          privateKey != null &&
          privateKey.isNotEmpty) {
        final derivedPublicKey = await _keyPairGenerator.publicKeyFromPrivate(
          privateKey,
        );
        if (derivedPublicKey != storedPublicKey) {
          throw const IdentityError(
            IdentityErrorCode.publicKeyMismatch,
            'Локальный private key не соответствует public identity.',
          );
        }
        return PublicIdentity(
          userId: userId,
          deviceId: currentDeviceId,
          publicKey: storedPublicKey,
        );
      }
    }

    if (!storedPublicKey.startsWith('local-unverified:')) {
      throw const IdentityError(
        IdentityErrorCode.privateKeyUnavailable,
        'Private key локальной identity недоступен.',
      );
    }

    final deviceId = _idGenerator.nextId();
    final keyPair = await _keyPairGenerator.generate();
    await _keyStore.saveIdentity(
      userId: userId,
      deviceId: deviceId,
      privateKey: keyPair.privateKey,
    );

    try {
      await _identityRepository.migrateLegacyIdentity(
        userId: userId,
        publicKey: keyPair.publicKey,
        deviceId: deviceId,
      );
    } on Object {
      await _keyStore.deleteIdentity(userId: userId, deviceId: deviceId);
      rethrow;
    }

    return PublicIdentity(
      userId: userId,
      deviceId: deviceId,
      publicKey: keyPair.publicKey,
    );
  }
}

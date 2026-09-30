import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/ports/invite_consumption_store.dart';

final class SecureInviteConsumptionStore implements InviteConsumptionStore {
  SecureInviteConsumptionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String inviteId) => 'invite.consumed.$inviteId';

  @override
  Future<bool> isConsumed(String inviteId) async {
    return await _storage.read(key: _key(inviteId)) == '1';
  }

  @override
  Future<void> markConsumed(String inviteId) {
    return _storage.write(key: _key(inviteId), value: '1');
  }

  @override
  Future<void> unmarkConsumed(String inviteId) {
    return _storage.delete(key: _key(inviteId));
  }
}

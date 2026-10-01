import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/ports/database_key_store.dart';

final class FlutterSecureDatabaseKeyStore implements DatabaseKeyStore {
  FlutterSecureDatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyName = 'database.budget_accounting.key.v1';

  @override
  Future<String?> loadKey() => _storage.read(key: _keyName);

  @override
  Future<void> saveKey(String key) {
    return _storage.write(key: _keyName, value: key);
  }

  @override
  Future<void> deleteKey() => _storage.delete(key: _keyName);
}

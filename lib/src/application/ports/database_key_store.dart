abstract interface class DatabaseKeyStore {
  Future<String?> loadKey();

  Future<void> saveKey(String key);

  Future<void> deleteKey();
}

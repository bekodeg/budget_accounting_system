import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/ports/budget_transport_secret_store.dart';

final class FlutterSecureBudgetTransportSecretStore
    implements BudgetTransportSecretStore {
  FlutterSecureBudgetTransportSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String budgetId) => 'budget.$budgetId.transport.secret';

  @override
  Future<String?> load(String budgetId) => _storage.read(key: _key(budgetId));

  @override
  Future<void> save({
    required String budgetId,
    required String secret,
  }) {
    return _storage.write(key: _key(budgetId), value: secret);
  }

  @override
  Future<void> delete(String budgetId) {
    return _storage.delete(key: _key(budgetId));
  }
}

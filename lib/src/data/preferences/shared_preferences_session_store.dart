import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/session_store.dart';

final class SharedPreferencesSessionStore implements SessionStore {
  SharedPreferencesSessionStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _currentUserIdKey = 'session.current_user_id';
  static const _currentBudgetIdKey = 'session.current_budget_id';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> loadCurrentUserId() {
    return _preferences.getString(_currentUserIdKey);
  }

  @override
  Future<String?> loadCurrentBudgetId() {
    return _preferences.getString(_currentBudgetIdKey);
  }

  @override
  Future<void> saveCurrentUserId(String userId) {
    return _preferences.setString(_currentUserIdKey, userId);
  }

  @override
  Future<void> saveCurrentBudgetId(String budgetId) {
    return _preferences.setString(_currentBudgetIdKey, budgetId);
  }

  @override
  Future<void> saveSession({
    required String userId,
    required String budgetId,
  }) async {
    await saveCurrentUserId(userId);
    await saveCurrentBudgetId(budgetId);
  }
}

abstract interface class SessionStore {
  Future<String?> loadCurrentUserId();

  Future<String?> loadCurrentBudgetId();

  Future<void> saveCurrentUserId(String userId);

  Future<void> saveCurrentBudgetId(String budgetId);

  Future<void> saveSession({required String userId, required String budgetId});
}

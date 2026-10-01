abstract interface class BudgetTransportSecretStore {
  Future<String?> load(String budgetId);

  Future<void> save({
    required String budgetId,
    required String secret,
  });

  Future<void> delete(String budgetId);
}

abstract interface class BudgetBackupFileGateway {
  Future<void> share({
    required String fileName,
    required String payload,
  });

  Future<String?> pick();
}

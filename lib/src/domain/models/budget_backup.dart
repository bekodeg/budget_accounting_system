final class BudgetBackupPreview {
  const BudgetBackupPreview({
    required this.formatVersion,
    required this.sourceBudgetId,
    required this.budgetName,
    required this.baseCurrency,
    required this.createdAt,
    required this.memberCount,
    required this.categoryCount,
    required this.accountCount,
    required this.transactionCount,
    required this.planCount,
    required this.receiptCount,
  });

  final int formatVersion;
  final String sourceBudgetId;
  final String budgetName;
  final String baseCurrency;
  final DateTime createdAt;
  final int memberCount;
  final int categoryCount;
  final int accountCount;
  final int transactionCount;
  final int planCount;
  final int receiptCount;
}

final class BudgetBackupRestoreResult {
  const BudgetBackupRestoreResult({
    required this.budgetId,
    required this.restoredAsNewBudget,
  });

  final String budgetId;
  final bool restoredAsNewBudget;
}

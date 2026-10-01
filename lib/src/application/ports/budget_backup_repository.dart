import '../../domain/models/budget_backup.dart';

abstract interface class BudgetBackupRepository {
  Future<String> createEncrypted({
    required String budgetId,
    required String password,
  });

  Future<BudgetBackupPreview> preview({
    required String payload,
    required String password,
  });

  Future<BudgetBackupRestoreResult> restore({
    required String payload,
    required String password,
  });
}

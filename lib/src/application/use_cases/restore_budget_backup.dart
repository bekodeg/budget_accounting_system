import '../../domain/models/budget_backup.dart';
import '../ports/budget_backup_repository.dart';

final class RestoreBudgetBackup {
  const RestoreBudgetBackup(this._repository);

  final BudgetBackupRepository _repository;

  Future<BudgetBackupRestoreResult> call({
    required String payload,
    required String password,
  }) {
    return _repository.restore(payload: payload, password: password);
  }
}

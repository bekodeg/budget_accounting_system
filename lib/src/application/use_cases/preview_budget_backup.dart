import '../../domain/models/budget_backup.dart';
import '../ports/budget_backup_repository.dart';

final class PreviewBudgetBackup {
  const PreviewBudgetBackup(this._repository);

  final BudgetBackupRepository _repository;

  Future<BudgetBackupPreview> call({
    required String payload,
    required String password,
  }) {
    return _repository.preview(payload: payload, password: password);
  }
}

import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../ports/budget_backup_file_gateway.dart';
import '../ports/budget_backup_repository.dart';

final class ExportBudgetBackup {
  const ExportBudgetBackup({
    required BudgetBackupRepository repository,
    required BudgetBackupFileGateway fileGateway,
    required BudgetAuthorizationGuard authorization,
  }) : _repository = repository,
       _fileGateway = fileGateway,
       _authorization = authorization;

  final BudgetBackupRepository _repository;
  final BudgetBackupFileGateway _fileGateway;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String password,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.export,
    );
    final payload = await _repository.createEncrypted(
      budgetId: budgetId,
      password: password,
    );
    await _fileGateway.share(
      fileName: 'budget-$budgetId-backup.budgetbackup',
      payload: payload,
    );
  }
}

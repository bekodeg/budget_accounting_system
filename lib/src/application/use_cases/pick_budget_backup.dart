import '../ports/budget_backup_file_gateway.dart';

final class PickBudgetBackup {
  const PickBudgetBackup(this._gateway);

  final BudgetBackupFileGateway _gateway;

  Future<String?> call() => _gateway.pick();
}

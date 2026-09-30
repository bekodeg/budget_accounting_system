import '../../domain/models/budget_snapshot.dart';
import '../../application/ports/budget_snapshot_repository.dart';

final class CreateBudgetSnapshot {
  const CreateBudgetSnapshot(this._repository);

  final BudgetSnapshotRepository _repository;

  Future<BudgetSnapshotPackage> call(String budgetId) {
    return _repository.create(budgetId);
  }
}

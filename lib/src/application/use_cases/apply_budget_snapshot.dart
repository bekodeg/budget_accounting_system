import '../../domain/models/budget_snapshot.dart';
import '../../application/ports/budget_snapshot_repository.dart';

final class ApplyBudgetSnapshot {
  const ApplyBudgetSnapshot(this._repository);

  final BudgetSnapshotRepository _repository;

  Future<void> call({
    required String budgetId,
    required BudgetSnapshotPackage snapshot,
  }) {
    return _repository.apply(expectedBudgetId: budgetId, snapshot: snapshot);
  }
}

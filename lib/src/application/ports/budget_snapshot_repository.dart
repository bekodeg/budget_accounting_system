import '../../domain/models/budget_snapshot.dart';

abstract interface class BudgetSnapshotRepository {
  Future<BudgetSnapshotPackage> create(String budgetId);

  Future<void> apply({
    required String expectedBudgetId,
    required BudgetSnapshotPackage snapshot,
  });
}

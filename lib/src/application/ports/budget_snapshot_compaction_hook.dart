import '../../domain/models/budget_snapshot.dart';

abstract interface class BudgetSnapshotCompactionHook {
  Future<void> onSnapshotConfirmed({
    required String budgetId,
    required BudgetSnapshotPackage snapshot,
  });
}

final class BudgetSnapshotPackage {
  const BudgetSnapshotPackage({
    required this.bodyJson,
    required this.digestBase64,
  });

  final String bodyJson;
  final String digestBase64;
}

final class BudgetSnapshotMetadata {
  const BudgetSnapshotMetadata({
    required this.version,
    required this.budgetId,
    required this.createdAt,
  });

  final int version;
  final String budgetId;
  final DateTime createdAt;
}

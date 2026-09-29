final class MonthlyPlan {
  const MonthlyPlan({
    required this.id,
    required this.budgetId,
    required this.month,
    required this.categoryId,
    required this.plannedAmountMinor,
    required this.updatedAt,
  });

  final String id;
  final String budgetId;
  final DateTime month;
  final String categoryId;
  final BigInt plannedAmountMinor;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyPlan &&
          other.id == id &&
          other.budgetId == budgetId &&
          other.month == month &&
          other.categoryId == categoryId &&
          other.plannedAmountMinor == plannedAmountMinor &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        budgetId,
        month,
        categoryId,
        plannedAmountMinor,
        updatedAt,
      );
}

DateTime normalizePlanMonth(DateTime value) => DateTime(value.year, value.month);

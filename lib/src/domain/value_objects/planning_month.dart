final class PlanningMonth {
  PlanningMonth(DateTime value)
      : value = DateTime(value.year, value.month);

  final DateTime value;

  int get year => value.year;
  int get month => value.month;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanningMonth && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}

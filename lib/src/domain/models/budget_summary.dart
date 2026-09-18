final class BudgetSummary {
  const BudgetSummary({
    required this.id,
    required this.name,
    required this.baseCurrency,
  });

  final String id;
  final String name;
  final String baseCurrency;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BudgetSummary &&
            other.id == id &&
            other.name == name &&
            other.baseCurrency == baseCurrency;
  }

  @override
  int get hashCode => Object.hash(id, name, baseCurrency);

  @override
  String toString() {
    return 'BudgetSummary(id: $id, name: $name, baseCurrency: $baseCurrency)';
  }
}

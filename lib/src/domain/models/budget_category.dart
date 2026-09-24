import 'domain_types.dart';

final class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.kind,
    required this.isArchived,
  });

  final String id;
  final String budgetId;
  final String name;
  final CategoryKind kind;
  final bool isArchived;

  BudgetCategory copyWith({
    String? name,
    CategoryKind? kind,
    bool? isArchived,
  }) {
    return BudgetCategory(
      id: id,
      budgetId: budgetId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetCategory &&
          other.id == id &&
          other.budgetId == budgetId &&
          other.name == name &&
          other.kind == kind &&
          other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(id, budgetId, name, kind, isArchived);
}

import '../value_objects/currency.dart';

final class BudgetAccount {
  const BudgetAccount({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.openingBalanceMinor,
    required this.currency,
    required this.isArchived,
  });

  final String id;
  final String budgetId;
  final String name;
  final BigInt openingBalanceMinor;
  final Currency currency;
  final bool isArchived;

  BudgetAccount copyWith({
    String? name,
    BigInt? openingBalanceMinor,
    Currency? currency,
    bool? isArchived,
  }) {
    return BudgetAccount(
      id: id,
      budgetId: budgetId,
      name: name ?? this.name,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      currency: currency ?? this.currency,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetAccount &&
          other.id == id &&
          other.budgetId == budgetId &&
          other.name == name &&
          other.openingBalanceMinor == openingBalanceMinor &&
          other.currency == currency &&
          other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(
    id,
    budgetId,
    name,
    openingBalanceMinor,
    currency,
    isArchived,
  );
}

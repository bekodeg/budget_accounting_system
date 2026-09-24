import 'domain_types.dart';

final class TransactionFilter {
  const TransactionFilter({
    required this.budgetId,
    this.fromInclusive,
    this.toExclusive,
    this.type,
    this.categoryId,
    this.accountId,
    this.authorId,
  });

  final String budgetId;
  final DateTime? fromInclusive;
  final DateTime? toExclusive;
  final TransactionType? type;
  final String? categoryId;
  final String? accountId;
  final String? authorId;

  bool get isEmpty =>
      fromInclusive == null &&
      toExclusive == null &&
      type == null &&
      categoryId == null &&
      accountId == null &&
      authorId == null;
}

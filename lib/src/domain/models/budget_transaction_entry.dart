import '../value_objects/money.dart';
import 'domain_types.dart';

final class BudgetTransactionEntry {
  const BudgetTransactionEntry({
    required this.id,
    required this.budgetId,
    required this.occurredAt,
    required this.amount,
    required this.type,
    required this.authorId,
    required this.accountId,
    required this.destinationAccountId,
    required this.categoryId,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String budgetId;
  final DateTime occurredAt;
  final Money amount;
  final TransactionType type;
  final String authorId;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
}

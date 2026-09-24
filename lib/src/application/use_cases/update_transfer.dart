import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/money.dart';
import '../errors/transaction_error.dart';
import 'require_account_in_budget.dart';

final class UpdateTransfer {
  const UpdateTransfer({
    required TransactionRepository transactionRepository,
    required RequireAccountInBudget requireAccountInBudget,
  })  : _transactionRepository = transactionRepository,
        _requireAccountInBudget = requireAccountInBudget;

  final TransactionRepository _transactionRepository;
  final RequireAccountInBudget _requireAccountInBudget;

  Future<BudgetTransactionEntry> call({
    required String budgetId,
    required String transactionId,
    required DateTime occurredAt,
    required BigInt amountMinor,
    required String sourceAccountId,
    required String destinationAccountId,
    String? description,
  }) async {
    final current = await _transactionRepository.findActiveTransaction(
      budgetId: budgetId,
      transactionId: transactionId,
    );
    if (current == null) {
      throw const TransactionError(
        code: TransactionErrorCode.transactionNotFound,
        message: 'Операция не найдена.',
      );
    }

    final source = await _requireAccountInBudget(
      budgetId: budgetId,
      accountId: sourceAccountId,
    );
    final destination = await _requireAccountInBudget(
      budgetId: budgetId,
      accountId: destinationAccountId,
    );
    final amount = Money.positive(
      minorUnits: amountMinor,
      currency: source.currency,
    );

    TransactionDraft(
      type: TransactionType.transfer,
      amount: amount,
      accountId: source.id,
      accountCurrency: source.currency,
      destinationAccountId: destination.id,
      destinationAccountCurrency: destination.currency,
      description: description,
    );

    final updated = BudgetTransactionEntry(
      id: current.id,
      budgetId: current.budgetId,
      occurredAt: occurredAt,
      amount: amount,
      type: TransactionType.transfer,
      authorId: current.authorId,
      accountId: source.id,
      destinationAccountId: destination.id,
      categoryId: null,
      description: _normalizeDescription(description),
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    final didUpdate = await _transactionRepository.updateTransaction(updated);
    if (!didUpdate) {
      throw const TransactionError(
        code: TransactionErrorCode.transactionNotFound,
        message: 'Операция не найдена.',
      );
    }
    return updated;
  }
}

String? _normalizeDescription(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/money.dart';
import '../errors/transaction_error.dart';
import 'require_account_in_budget.dart';
import 'require_category_in_budget.dart';

final class UpdateTransaction {
  const UpdateTransaction({
    required TransactionRepository transactionRepository,
    required RequireAccountInBudget requireAccountInBudget,
    required RequireCategoryInBudget requireCategoryInBudget,
  })  : _transactionRepository = transactionRepository,
        _requireAccountInBudget = requireAccountInBudget,
        _requireCategoryInBudget = requireCategoryInBudget;

  final TransactionRepository _transactionRepository;
  final RequireAccountInBudget _requireAccountInBudget;
  final RequireCategoryInBudget _requireCategoryInBudget;

  Future<BudgetTransactionEntry> call({
    required String budgetId,
    required String transactionId,
    required DateTime occurredAt,
    required BigInt amountMinor,
    required TransactionType type,
    required String accountId,
    required String categoryId,
    String? description,
  }) async {
    if (type == TransactionType.transfer) {
      throw const TransactionError(
        code: TransactionErrorCode.invalidCategory,
        message: 'Переводы редактируются отдельным сценарием.',
      );
    }

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

    final account = await _requireAccountInBudget(
      budgetId: budgetId,
      accountId: accountId,
    );
    await _requireCategoryInBudget(
      budgetId: budgetId,
      categoryId: categoryId,
      transactionType: type,
    );

    final amount = Money.positive(
      minorUnits: amountMinor,
      currency: account.currency,
    );
    TransactionDraft(
      type: type,
      amount: amount,
      accountId: account.id,
      accountCurrency: account.currency,
      categoryId: categoryId,
      description: description,
    );

    final updated = BudgetTransactionEntry(
      id: current.id,
      budgetId: current.budgetId,
      occurredAt: occurredAt,
      amount: amount,
      type: type,
      authorId: current.authorId,
      accountId: account.id,
      destinationAccountId: null,
      categoryId: categoryId,
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

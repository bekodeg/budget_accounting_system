import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/money.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/authorization_error.dart';
import '../errors/transaction_error.dart';
import '../ports/id_generator.dart';
import 'require_account_in_budget.dart';
import 'require_category_in_budget.dart';

final class CreateTransaction {
  const CreateTransaction({
    required TransactionRepository transactionRepository,
    required RequireAccountInBudget requireAccountInBudget,
    required RequireCategoryInBudget requireCategoryInBudget,
    required IdGenerator idGenerator,
    required BudgetAuthorizationGuard authorization,
  }) : _transactionRepository = transactionRepository,
       _requireAccountInBudget = requireAccountInBudget,
       _requireCategoryInBudget = requireCategoryInBudget,
       _idGenerator = idGenerator,
       _authorization = authorization;

  final TransactionRepository _transactionRepository;
  final RequireAccountInBudget _requireAccountInBudget;
  final RequireCategoryInBudget _requireCategoryInBudget;
  final IdGenerator _idGenerator;
  final BudgetAuthorizationGuard _authorization;

  Future<BudgetTransactionEntry> call({
    required String budgetId,
    required String authorId,
    required DateTime occurredAt,
    required BigInt amountMinor,
    required TransactionType type,
    required String accountId,
    required String categoryId,
    String? description,
  }) async {
    final member = await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );
    if (authorId != member.userId) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.forbidden,
        message: 'Нельзя создавать операцию от имени другого участника.',
      );
    }

    if (type == TransactionType.transfer) {
      throw const TransactionError(
        code: TransactionErrorCode.invalidCategory,
        message: 'Переводы создаются отдельным сценарием.',
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

    final now = DateTime.now();
    final transaction = BudgetTransactionEntry(
      id: _idGenerator.nextId(),
      budgetId: budgetId,
      occurredAt: occurredAt,
      amount: amount,
      type: type,
      authorId: authorId,
      accountId: account.id,
      destinationAccountId: null,
      categoryId: categoryId,
      description: _normalizeDescription(description),
      createdAt: now,
      updatedAt: now,
    );

    await _transactionRepository.createTransaction(transaction);
    return transaction;
  }
}

String? _normalizeDescription(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/transaction_draft.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/money.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/authorization_error.dart';
import '../ports/id_generator.dart';
import 'require_account_in_budget.dart';

final class CreateTransfer {
  const CreateTransfer({
    required TransactionRepository transactionRepository,
    required RequireAccountInBudget requireAccountInBudget,
    required IdGenerator idGenerator,
    required BudgetAuthorizationGuard authorization,
  }) : _transactionRepository = transactionRepository,
       _requireAccountInBudget = requireAccountInBudget,
       _idGenerator = idGenerator,
       _authorization = authorization;

  final TransactionRepository _transactionRepository;
  final RequireAccountInBudget _requireAccountInBudget;
  final IdGenerator _idGenerator;
  final BudgetAuthorizationGuard _authorization;

  Future<BudgetTransactionEntry> call({
    required String budgetId,
    required String authorId,
    required DateTime occurredAt,
    required BigInt amountMinor,
    required String sourceAccountId,
    required String destinationAccountId,
    String? description,
  }) async {
    final member = await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );
    if (authorId != member.userId) {
      throw const AuthorizationError(
        code: AuthorizationErrorCode.forbidden,
        message: 'Нельзя создавать перевод от имени другого участника.',
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

    final now = DateTime.now();
    final transaction = BudgetTransactionEntry(
      id: _idGenerator.nextId(),
      budgetId: budgetId,
      occurredAt: occurredAt,
      amount: amount,
      type: TransactionType.transfer,
      authorId: authorId,
      accountId: source.id,
      destinationAccountId: destination.id,
      categoryId: null,
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

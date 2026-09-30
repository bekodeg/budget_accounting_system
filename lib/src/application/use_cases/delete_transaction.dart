import '../../domain/repositories/transaction_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/transaction_error.dart';

final class DeleteTransaction {
  const DeleteTransaction({
    required TransactionRepository repository,
    required BudgetAuthorizationGuard authorization,
  }) : _repository = repository,
       _authorization = authorization;

  final TransactionRepository _repository;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String transactionId,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    final deleted = await _repository.softDeleteTransaction(
      budgetId: budgetId,
      transactionId: transactionId,
      deletedAt: DateTime.now(),
    );
    if (!deleted) {
      throw const TransactionError(
        code: TransactionErrorCode.transactionNotFound,
        message: 'Операция не найдена.',
      );
    }
  }
}

import '../../domain/repositories/transaction_repository.dart';
import '../errors/transaction_error.dart';

final class DeleteTransaction {
  const DeleteTransaction(this._repository);

  final TransactionRepository _repository;

  Future<void> call({
    required String budgetId,
    required String transactionId,
  }) async {
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

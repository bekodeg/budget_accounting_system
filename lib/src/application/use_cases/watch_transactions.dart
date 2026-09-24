import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/repositories/transaction_repository.dart';

final class WatchTransactions {
  const WatchTransactions(this._repository);

  final TransactionRepository _repository;

  Stream<List<BudgetTransactionEntry>> call(String budgetId) {
    return _repository.watchActiveTransactions(budgetId);
  }
}

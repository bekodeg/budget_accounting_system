import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/transaction_filter.dart';
import '../../domain/repositories/transaction_repository.dart';

final class WatchFilteredTransactions {
  const WatchFilteredTransactions(this._repository);

  final TransactionRepository _repository;

  Stream<List<BudgetTransactionEntry>> call(TransactionFilter filter) {
    return _repository.watchFilteredTransactions(filter);
  }
}

import '../models/budget_transaction_entry.dart';
import '../models/transaction_filter.dart';

abstract interface class TransactionRepository {
  Stream<List<BudgetTransactionEntry>> watchActiveTransactions(String budgetId);

  Stream<List<BudgetTransactionEntry>> watchFilteredTransactions(
    TransactionFilter filter,
  );

  Future<BudgetTransactionEntry?> findActiveTransaction({
    required String budgetId,
    required String transactionId,
  });

  Future<void> createTransaction(BudgetTransactionEntry transaction);

  Future<bool> updateTransaction(BudgetTransactionEntry transaction);

  Future<bool> softDeleteTransaction({
    required String budgetId,
    required String transactionId,
    required DateTime deletedAt,
  });
}

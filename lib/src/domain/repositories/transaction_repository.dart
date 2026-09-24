import '../models/budget_transaction_entry.dart';

abstract interface class TransactionRepository {
  Stream<List<BudgetTransactionEntry>> watchActiveTransactions(String budgetId);

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

import '../../application/ports/sync_mutation_context_provider.dart';
import '../../application/ports/sync_mutation_executor.dart';
import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/sync_mutation.dart';
import '../../domain/models/transaction_filter.dart';
import '../../domain/repositories/transaction_repository.dart';

final class SyncingTransactionRepository implements TransactionRepository {
  const SyncingTransactionRepository({
    required TransactionRepository delegate,
    required SyncMutationExecutor executor,
    required SyncMutationContextProvider contextProvider,
  }) : _delegate = delegate,
       _executor = executor,
       _contextProvider = contextProvider;

  final TransactionRepository _delegate;
  final SyncMutationExecutor _executor;
  final SyncMutationContextProvider _contextProvider;

  @override
  Stream<List<BudgetTransactionEntry>> watchActiveTransactions(String budgetId) =>
      _delegate.watchActiveTransactions(budgetId);

  @override
  Stream<List<BudgetTransactionEntry>> watchFilteredTransactions(
    TransactionFilter filter,
  ) => _delegate.watchFilteredTransactions(filter);

  @override
  Future<BudgetTransactionEntry?> findActiveTransaction({
    required String budgetId,
    required String transactionId,
  }) =>
      _delegate.findActiveTransaction(
        budgetId: budgetId,
        transactionId: transactionId,
      );

  @override
  Future<void> createTransaction(BudgetTransactionEntry transaction) async {
    final context = await _contextProvider.current();
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: transaction.budgetId,
          entityType: 'transaction',
          entityId: transaction.id,
          type: SyncMutationType.create,
          patch: _transactionPatch(transaction),
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.createTransaction(transaction),
    );
  }

  @override
  Future<bool> updateTransaction(BudgetTransactionEntry transaction) async {
    final context = await _contextProvider.current();
    return _executor.execute<bool>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: transaction.budgetId,
          entityType: 'transaction',
          entityId: transaction.id,
          type: SyncMutationType.patch,
          patch: _transactionPatch(transaction),
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.updateTransaction(transaction),
      shouldRecord: (changed) => changed,
    );
  }

  @override
  Future<bool> softDeleteTransaction({
    required String budgetId,
    required String transactionId,
    required DateTime deletedAt,
  }) async {
    final context = await _contextProvider.current();
    return _executor.execute<bool>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: budgetId,
          entityType: 'transaction',
          entityId: transactionId,
          type: SyncMutationType.delete,
          patch: {'deleted_at': deletedAt},
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.softDeleteTransaction(
        budgetId: budgetId,
        transactionId: transactionId,
        deletedAt: deletedAt,
      ),
      shouldRecord: (changed) => changed,
    );
  }
}

Map<String, Object?> _transactionPatch(BudgetTransactionEntry value) => {
  'occurred_at': value.occurredAt,
  'amount_minor': value.amount.minorUnits,
  'currency': value.amount.currency.code,
  'type': value.type.name.toUpperCase(),
  'author_id': value.authorId,
  'account_id': value.accountId,
  'destination_account_id': value.destinationAccountId,
  'category_id': value.categoryId,
  'description': value.description,
  'created_at': value.createdAt,
  'updated_at': value.updatedAt,
};

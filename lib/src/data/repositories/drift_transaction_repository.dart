import 'package:drift/drift.dart';

import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/transaction_filter.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/money.dart';
import '../dal/transaction_dao.dart';
import '../database/app_database.dart';

final class DriftTransactionRepository implements TransactionRepository {
  const DriftTransactionRepository(this._dao);

  final TransactionDao _dao;

  @override
  Stream<List<BudgetTransactionEntry>> watchActiveTransactions(
    String budgetId,
  ) {
    return _dao
        .watchActive(budgetId)
        .map((items) => items.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<List<BudgetTransactionEntry>> watchFilteredTransactions(
    TransactionFilter filter,
  ) {
    return _dao
        .watchFiltered(
          budgetId: filter.budgetId,
          fromInclusive: filter.fromInclusive,
          toExclusive: filter.toExclusive,
          type: filter.type == null ? null : _typeToStorage(filter.type!),
          categoryId: filter.categoryId,
          accountId: filter.accountId,
          authorId: filter.authorId,
        )
        .map((items) => items.map(_toDomain).toList(growable: false));
  }

  @override
  Future<BudgetTransactionEntry?> findActiveTransaction({
    required String budgetId,
    required String transactionId,
  }) async {
    final item = await _dao.findActive(
      budgetId: budgetId,
      transactionId: transactionId,
    );
    return item == null ? null : _toDomain(item);
  }

  @override
  Future<void> createTransaction(BudgetTransactionEntry transaction) {
    return _dao.upsert(
      BudgetTransactionsCompanion.insert(
        id: transaction.id,
        budgetId: transaction.budgetId,
        occurredAt: transaction.occurredAt,
        amountMinor: transaction.amount.minorUnits,
        currency: transaction.amount.currency.code,
        type: _typeToStorage(transaction.type),
        authorId: transaction.authorId,
        accountId: transaction.accountId,
        destinationAccountId: Value(transaction.destinationAccountId),
        description: Value(transaction.description),
        categoryId: Value(transaction.categoryId),
        createdAt: Value(transaction.createdAt),
        updatedAt: Value(transaction.updatedAt),
      ),
    );
  }

  @override
  Future<bool> updateTransaction(BudgetTransactionEntry transaction) async {
    final count = await _dao.updateActive(
      budgetId: transaction.budgetId,
      transactionId: transaction.id,
      changes: BudgetTransactionsCompanion(
        budgetId: Value(transaction.budgetId),
        occurredAt: Value(transaction.occurredAt),
        amountMinor: Value(transaction.amount.minorUnits),
        currency: Value(transaction.amount.currency.code),
        type: Value(_typeToStorage(transaction.type)),
        authorId: Value(transaction.authorId),
        accountId: Value(transaction.accountId),
        destinationAccountId: Value(transaction.destinationAccountId),
        description: Value(transaction.description),
        categoryId: Value(transaction.categoryId),
        updatedAt: Value(transaction.updatedAt),
      ),
    );
    return count == 1;
  }

  @override
  Future<bool> softDeleteTransaction({
    required String budgetId,
    required String transactionId,
    required DateTime deletedAt,
  }) async {
    final count = await _dao.softDelete(
      budgetId: budgetId,
      id: transactionId,
      deletedAt: deletedAt,
    );
    return count == 1;
  }

  BudgetTransactionEntry _toDomain(BudgetTransaction item) {
    return BudgetTransactionEntry(
      id: item.id,
      budgetId: item.budgetId,
      occurredAt: item.occurredAt,
      amount: Money.positive(
        minorUnits: item.amountMinor,
        currency: Currency(item.currency),
      ),
      type: _typeFromStorage(item.type),
      authorId: item.authorId,
      accountId: item.accountId,
      destinationAccountId: item.destinationAccountId,
      categoryId: item.categoryId,
      description: item.description,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}

TransactionType _typeFromStorage(String value) {
  return switch (value) {
    'INCOME' => TransactionType.income,
    'EXPENSE' => TransactionType.expense,
    'TRANSFER' => TransactionType.transfer,
    _ => throw StateError('Unsupported transaction type: $value'),
  };
}

String _typeToStorage(TransactionType type) {
  return switch (type) {
    TransactionType.income => 'INCOME',
    TransactionType.expense => 'EXPENSE',
    TransactionType.transfer => 'TRANSFER',
  };
}

import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class TransactionDao {
  TransactionDao(this._db);

  final AppDatabase _db;

  Future<void> upsert(BudgetTransactionsCompanion transaction) async {
    await _validateAccountOwnership(transaction);
    await _db.into(_db.budgetTransactions).insertOnConflictUpdate(transaction);
  }

  Future<BudgetTransaction?> findActive({
    required String budgetId,
    required String transactionId,
  }) {
    return (_db.select(_db.budgetTransactions)
          ..where(
            (row) =>
                row.id.equals(transactionId) &
                row.budgetId.equals(budgetId) &
                row.deletedAt.isNull(),
          ))
        .getSingleOrNull();
  }

  Future<BudgetTransaction?> findById(String id) {
    return (_db.select(
      _db.budgetTransactions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Stream<List<BudgetTransaction>> watchActive(String budgetId) {
    return (_db.select(_db.budgetTransactions)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) & row.deletedAt.isNull(),
          )
          ..orderBy([
            (row) => OrderingTerm.desc(row.occurredAt),
            (row) => OrderingTerm.desc(row.updatedAt),
            (row) => OrderingTerm.desc(row.id),
          ]))
        .watch();
  }

  Stream<List<BudgetTransaction>> watchFiltered({
    required String budgetId,
    DateTime? fromInclusive,
    DateTime? toExclusive,
    String? type,
    String? categoryId,
    String? accountId,
    String? authorId,
  }) {
    final query = _db.select(_db.budgetTransactions)
      ..where(
        (row) => row.budgetId.equals(budgetId) & row.deletedAt.isNull(),
      );

    if (fromInclusive != null) {
      query.where(
        (row) => row.occurredAt.isBiggerOrEqualValue(fromInclusive),
      );
    }
    if (toExclusive != null) {
      query.where(
        (row) => row.occurredAt.isSmallerThanValue(toExclusive),
      );
    }
    if (type != null) {
      query.where((row) => row.type.equals(type));
    }
    if (categoryId != null) {
      query.where((row) => row.categoryId.equals(categoryId));
    }
    if (accountId != null) {
      query.where(
        (row) =>
            row.accountId.equals(accountId) |
            row.destinationAccountId.equals(accountId),
      );
    }
    if (authorId != null) {
      query.where((row) => row.authorId.equals(authorId));
    }

    query.orderBy([
      (row) => OrderingTerm.desc(row.occurredAt),
      (row) => OrderingTerm.desc(row.updatedAt),
      (row) => OrderingTerm.desc(row.id),
    ]);
    return query.watch();
  }

  Stream<List<BudgetTransaction>> watchPeriod({
    required String budgetId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) {
    return (_db.select(_db.budgetTransactions)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.occurredAt.isBiggerOrEqualValue(fromInclusive) &
                row.occurredAt.isSmallerThanValue(toExclusive) &
                row.deletedAt.isNull(),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .watch();
  }

  Future<int> updateActive({
    required String budgetId,
    required String transactionId,
    required BudgetTransactionsCompanion changes,
  }) async {
    await _validateAccountOwnership(changes);
    return (_db.update(_db.budgetTransactions)
          ..where(
            (row) =>
                row.id.equals(transactionId) &
                row.budgetId.equals(budgetId) &
                row.deletedAt.isNull(),
          ))
        .write(changes);
  }

  Future<int> softDelete({
    required String budgetId,
    required String id,
    required DateTime deletedAt,
  }) {
    return (_db.update(_db.budgetTransactions)
          ..where(
            (row) =>
                row.id.equals(id) &
                row.budgetId.equals(budgetId) &
                row.deletedAt.isNull(),
          ))
        .write(
      BudgetTransactionsCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  Future<void> _validateAccountOwnership(
    BudgetTransactionsCompanion transaction,
  ) async {
    if (!transaction.budgetId.present || !transaction.accountId.present) {
      return;
    }

    final budgetId = transaction.budgetId.value;
    final sourceAccountId = transaction.accountId.value;
    if (!await _accountBelongsToBudget(
      budgetId: budgetId,
      accountId: sourceAccountId,
    )) {
      throw StateError(
        'Source account $sourceAccountId does not belong to budget $budgetId.',
      );
    }

    final destination = transaction.destinationAccountId;
    if (destination.present && destination.value != null) {
      final destinationId = destination.value!;
      if (!await _accountBelongsToBudget(
        budgetId: budgetId,
        accountId: destinationId,
      )) {
        throw StateError(
          'Destination account $destinationId does not belong to budget $budgetId.',
        );
      }
    }
  }

  Future<bool> _accountBelongsToBudget({
    required String budgetId,
    required String accountId,
  }) async {
    final account = await (_db.select(_db.accounts)
          ..where(
            (row) =>
                row.id.equals(accountId) & row.budgetId.equals(budgetId),
          )
          ..limit(1))
        .getSingleOrNull();
    return account != null;
  }
}

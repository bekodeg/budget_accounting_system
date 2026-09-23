import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class CategoryAccountDao {
  CategoryAccountDao(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchCategories(
    String budgetId, {
    required bool includeArchived,
  }) {
    final query = _db.select(_db.categories)
      ..where((row) {
        final sameBudget = row.budgetId.equals(budgetId);
        return includeArchived
            ? sameBudget
            : sameBudget & row.isArchived.equals(false);
      })
      ..orderBy([
        (row) => OrderingTerm.asc(row.kind),
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.id),
      ]);

    return query.watch();
  }

  Future<void> createCategory(CategoriesCompanion category) async {
    await _db.into(_db.categories).insert(category);
  }

  Future<void> upsertCategory(CategoriesCompanion category) async {
    await _db.into(_db.categories).insertOnConflictUpdate(category);
  }

  Future<void> insertCategoriesIfMissing(
    List<CategoriesCompanion> categories,
  ) {
    return _db.transaction(() async {
      for (final category in categories) {
        await _db
            .into(_db.categories)
            .insert(category, mode: InsertMode.insertOrIgnore);
      }
    });
  }

  Future<void> renameCategory({
    required String categoryId,
    required String name,
  }) async {
    await (_db.update(
      _db.categories,
    )..where((row) => row.id.equals(categoryId))).write(
      CategoriesCompanion(name: Value(name)),
    );
  }

  Future<void> setCategoryArchived({
    required String categoryId,
    required bool isArchived,
  }) async {
    await (_db.update(
      _db.categories,
    )..where((row) => row.id.equals(categoryId))).write(
      CategoriesCompanion(isArchived: Value(isArchived)),
    );
  }

  Stream<List<Account>> watchAccounts(
    String budgetId, {
    required bool includeArchived,
  }) {
    final query = _db.select(_db.accounts)
      ..where((row) {
        final sameBudget = row.budgetId.equals(budgetId);
        return includeArchived
            ? sameBudget
            : sameBudget & row.isArchived.equals(false);
      })
      ..orderBy([
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.id),
      ]);

    return query.watch();
  }

  Future<Account?> findAccount({
    required String budgetId,
    required String accountId,
  }) {
    return (_db.select(_db.accounts)
          ..where(
            (row) =>
                row.id.equals(accountId) & row.budgetId.equals(budgetId),
          ))
        .getSingleOrNull();
  }

  Future<void> createAccount(AccountsCompanion account) async {
    await _db.into(_db.accounts).insert(account);
  }

  Future<void> upsertAccount(AccountsCompanion account) async {
    await _db.into(_db.accounts).insertOnConflictUpdate(account);
  }

  Future<int> updateAccount({
    required String budgetId,
    required String accountId,
    required String name,
    required String currency,
    required BigInt openingBalanceMinor,
  }) {
    return (_db.update(_db.accounts)
          ..where(
            (row) =>
                row.id.equals(accountId) & row.budgetId.equals(budgetId),
          ))
        .write(
      AccountsCompanion(
        name: Value(name),
        currency: Value(currency),
        openingBalanceMinor: Value(openingBalanceMinor),
      ),
    );
  }

  Future<int> setAccountArchived({
    required String budgetId,
    required String accountId,
    required bool isArchived,
  }) {
    return (_db.update(_db.accounts)
          ..where(
            (row) =>
                row.id.equals(accountId) & row.budgetId.equals(budgetId),
          ))
        .write(
      AccountsCompanion(isArchived: Value(isArchived)),
    );
  }

  Future<bool> accountHasTransactions({
    required String budgetId,
    required String accountId,
  }) async {
    final transaction = _db.budgetTransactions;
    final query = _db.selectOnly(transaction)
      ..addColumns([transaction.id])
      ..where(
        transaction.budgetId.equals(budgetId) &
            transaction.deletedAt.isNull() &
            (transaction.accountId.equals(accountId) |
                transaction.destinationAccountId.equals(accountId)),
      )
      ..limit(1);

    return (await query.getSingleOrNull()) != null;
  }

  Future<BigInt> getAccountBalanceMinor({
    required String budgetId,
    required String accountId,
    required BigInt openingBalanceMinor,
  }) async {
    final transaction = _db.budgetTransactions;
    final rows = await (_db.select(transaction)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) &
                row.deletedAt.isNull() &
                (row.accountId.equals(accountId) |
                    row.destinationAccountId.equals(accountId)),
          ))
        .get();

    var balance = openingBalanceMinor;
    for (final item in rows) {
      if (item.type == 'INCOME' && item.accountId == accountId) {
        balance += item.amountMinor;
      } else if (item.type == 'EXPENSE' && item.accountId == accountId) {
        balance -= item.amountMinor;
      } else if (item.type == 'TRANSFER') {
        if (item.accountId == accountId) {
          balance -= item.amountMinor;
        }
        if (item.destinationAccountId == accountId) {
          balance += item.amountMinor;
        }
      }
    }

    return balance;
  }

  Future<List<CategoryTemplate>> getCategoryTemplates() {
    return (_db.select(_db.categoryTemplates)..orderBy([
          (row) => OrderingTerm.asc(row.kind),
          (row) => OrderingTerm.asc(row.sortOrder),
          (row) => OrderingTerm.asc(row.code),
        ]))
        .get();
  }
}

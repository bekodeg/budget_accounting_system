import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class AccountBalanceTotal {
  const AccountBalanceTotal({
    required this.accountId,
    required this.currency,
    required this.amountMinor,
  });

  final String accountId;
  final String currency;
  final BigInt amountMinor;
}

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

  Future<Category?> findCategory({
    required String budgetId,
    required String categoryId,
  }) {
    return (_db.select(_db.categories)..where(
          (row) => row.id.equals(categoryId) & row.budgetId.equals(budgetId),
        ))
        .getSingleOrNull();
  }

  Future<void> createCategory(CategoriesCompanion category) async {
    await _db.into(_db.categories).insert(category);
  }

  Future<void> upsertCategory(CategoriesCompanion category) async {
    await _db.into(_db.categories).insertOnConflictUpdate(category);
  }

  Future<void> insertCategoriesIfMissing(List<CategoriesCompanion> categories) {
    return _db.transaction(() async {
      for (final category in categories) {
        await _db
            .into(_db.categories)
            .insert(category, mode: InsertMode.insertOrIgnore);
      }
    });
  }

  Future<void> renameCategory({
    required String budgetId,
    required String categoryId,
    required String name,
  }) async {
    await (_db.update(_db.categories)..where(
          (row) => row.id.equals(categoryId) & row.budgetId.equals(budgetId),
        ))
        .write(CategoriesCompanion(name: Value(name)));
  }

  Future<void> setCategoryArchived({
    required String budgetId,
    required String categoryId,
    required bool isArchived,
  }) async {
    await (_db.update(_db.categories)..where(
          (row) => row.id.equals(categoryId) & row.budgetId.equals(budgetId),
        ))
        .write(CategoriesCompanion(isArchived: Value(isArchived)));
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
    return (_db.select(_db.accounts)..where(
          (row) => row.id.equals(accountId) & row.budgetId.equals(budgetId),
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
    return (_db.update(_db.accounts)..where(
          (row) => row.id.equals(accountId) & row.budgetId.equals(budgetId),
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
    return (_db.update(_db.accounts)..where(
          (row) => row.id.equals(accountId) & row.budgetId.equals(budgetId),
        ))
        .write(AccountsCompanion(isArchived: Value(isArchived)));
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
            (transaction.accountId.equals(accountId) |
                transaction.destinationAccountId.equals(accountId)),
      )
      ..limit(1);

    return (await query.getSingleOrNull()) != null;
  }

  Future<List<AccountBalanceTotal>> getAccountBalances({
    required String budgetId,
    required bool includeArchived,
    String? accountId,
    DateTime? atInclusive,
  }) async {
    final timePredicate = atInclusive == null ? '' : 'AND t.occurred_at <= ?';
    final archivedPredicate = includeArchived ? '' : 'AND a.is_archived = 0';
    final accountPredicate = accountId == null ? '' : 'AND a.id = ?';

    final rows = await _db
        .customSelect(
          '''
SELECT
  a.id AS account_id,
  a.currency AS currency,
  a.opening_balance_minor +
    COALESCE(
      SUM(
        CASE
          WHEN t.type = 'INCOME' AND t.account_id = a.id
            THEN t.amount_minor
          WHEN t.type = 'EXPENSE' AND t.account_id = a.id
            THEN -t.amount_minor
          WHEN t.type = 'TRANSFER' AND t.account_id = a.id
            THEN -t.amount_minor
          WHEN t.type = 'TRANSFER' AND t.destination_account_id = a.id
            THEN t.amount_minor
          ELSE 0
        END
      ),
      0
    ) AS balance_minor
FROM accounts a
LEFT JOIN transactions t
  ON t.budget_id = a.budget_id
  AND t.deleted_at IS NULL
  AND (t.account_id = a.id OR t.destination_account_id = a.id)
  $timePredicate
WHERE a.budget_id = ?
  $archivedPredicate
  $accountPredicate
GROUP BY a.id, a.currency, a.opening_balance_minor
ORDER BY a.name ASC, a.id ASC
''',
          variables: [
            if (atInclusive != null) Variable.withDateTime(atInclusive),
            Variable.withString(budgetId),
            if (accountId != null) Variable.withString(accountId),
          ],
          readsFrom: {_db.accounts, _db.budgetTransactions},
        )
        .get();

    return rows
        .map(
          (row) => AccountBalanceTotal(
            accountId: row.read<String>('account_id'),
            currency: row.read<String>('currency'),
            amountMinor: BigInt.from(row.read<int>('balance_minor')),
          ),
        )
        .toList(growable: false);
  }

  Future<BigInt> getAccountBalanceMinor({
    required String budgetId,
    required String accountId,
    required BigInt openingBalanceMinor,
    DateTime? atInclusive,
  }) async {
    final balances = await getAccountBalances(
      budgetId: budgetId,
      includeArchived: true,
      accountId: accountId,
      atInclusive: atInclusive,
    );
    return balances.isEmpty ? openingBalanceMinor : balances.single.amountMinor;
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

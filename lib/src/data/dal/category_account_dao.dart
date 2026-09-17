import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class CategoryAccountDao {
  CategoryAccountDao(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchCategories(String budgetId) {
    return (_db.select(_db.categories)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) & row.isArchived.equals(false),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .watch();
  }

  Future<void> upsertCategory(CategoriesCompanion category) async {
    await _db.into(_db.categories).insertOnConflictUpdate(category);
  }

  Stream<List<Account>> watchAccounts(String budgetId) {
    return (_db.select(_db.accounts)
          ..where(
            (row) =>
                row.budgetId.equals(budgetId) & row.isArchived.equals(false),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .watch();
  }

  Future<void> upsertAccount(AccountsCompanion account) async {
    await _db.into(_db.accounts).insertOnConflictUpdate(account);
  }

  Future<List<CategoryTemplate>> getCategoryTemplates() {
    return (_db.select(_db.categoryTemplates)
          ..orderBy([
            (row) => OrderingTerm.asc(row.kind),
            (row) => OrderingTerm.asc(row.sortOrder),
          ]))
        .get();
  }
}

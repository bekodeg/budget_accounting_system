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
    return (_db.select(_db.categoryTemplates)..orderBy([
          (row) => OrderingTerm.asc(row.kind),
          (row) => OrderingTerm.asc(row.sortOrder),
          (row) => OrderingTerm.asc(row.code),
        ]))
        .get();
  }
}

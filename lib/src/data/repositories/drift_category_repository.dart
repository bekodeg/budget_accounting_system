import 'package:drift/drift.dart';

import '../../domain/models/budget_category.dart';
import '../../domain/models/category_template.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/category_repository.dart';
import '../dal/category_account_dao.dart';
import '../database/app_database.dart';

final class DriftCategoryRepository implements CategoryRepository {
  const DriftCategoryRepository(this._dao);

  final CategoryAccountDao _dao;

  @override
  Stream<List<BudgetCategory>> watchCategories(
    String budgetId, {
    required bool includeArchived,
  }) {
    return _dao
        .watchCategories(
          budgetId,
          includeArchived: includeArchived,
        )
        .map(
          (categories) => categories
              .map(_toDomainCategory)
              .toList(growable: false),
        );
  }

  @override
  Future<List<CategoryTemplate>> getTemplates() async {
    final templates = await _dao.getCategoryTemplates();
    return templates
        .map(
          (template) => CategoryTemplate(
            code: template.code,
            name: template.name,
            kind: _categoryKindFromStorage(template.kind),
            sortOrder: template.sortOrder,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> insertCategoriesIfMissing(
    List<BudgetCategory> categories,
  ) {
    return _dao.insertCategoriesIfMissing(
      categories.map(_toCompanion).toList(growable: false),
    );
  }

  @override
  Future<void> createCategory(BudgetCategory category) {
    return _dao.createCategory(_toCompanion(category));
  }

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String name,
  }) {
    return _dao.renameCategory(
      categoryId: categoryId,
      name: name,
    );
  }

  @override
  Future<void> setCategoryArchived({
    required String categoryId,
    required bool isArchived,
  }) {
    return _dao.setCategoryArchived(
      categoryId: categoryId,
      isArchived: isArchived,
    );
  }

  BudgetCategory _toDomainCategory(Category category) {
    return BudgetCategory(
      id: category.id,
      budgetId: category.budgetId,
      name: category.name,
      kind: _categoryKindFromStorage(category.kind),
      isArchived: category.isArchived,
    );
  }

  CategoriesCompanion _toCompanion(BudgetCategory category) {
    return CategoriesCompanion.insert(
      id: category.id,
      budgetId: category.budgetId,
      name: category.name,
      kind: _categoryKindToStorage(category.kind),
      isArchived: Value(category.isArchived),
    );
  }
}

CategoryKind _categoryKindFromStorage(String value) {
  return switch (value) {
    'INCOME' => CategoryKind.income,
    'EXPENSE' => CategoryKind.expense,
    'BOTH' => CategoryKind.both,
    _ => throw StateError('Unsupported category kind: $value'),
  };
}

String _categoryKindToStorage(CategoryKind kind) {
  return switch (kind) {
    CategoryKind.income => 'INCOME',
    CategoryKind.expense => 'EXPENSE',
    CategoryKind.both => 'BOTH',
  };
}

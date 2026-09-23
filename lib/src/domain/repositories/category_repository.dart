import '../models/budget_category.dart';
import '../models/category_template.dart';

abstract interface class CategoryRepository {
  Stream<List<BudgetCategory>> watchCategories(
    String budgetId, {
    required bool includeArchived,
  });

  Future<List<CategoryTemplate>> getTemplates();

  Future<void> insertCategoriesIfMissing(List<BudgetCategory> categories);

  Future<void> createCategory(BudgetCategory category);

  Future<void> renameCategory({
    required String categoryId,
    required String name,
  });

  Future<void> setCategoryArchived({
    required String categoryId,
    required bool isArchived,
  });
}

import '../../domain/models/budget_category.dart';
import '../../domain/repositories/category_repository.dart';

final class ApplyCategoryTemplates {
  const ApplyCategoryTemplates(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String budgetId) async {
    final templates = await _repository.getTemplates();
    final categories = templates
        .map(
          (template) => BudgetCategory(
            id: templateCategoryId(
              budgetId: budgetId,
              templateCode: template.code,
            ),
            budgetId: budgetId,
            name: template.name,
            kind: template.kind,
            isArchived: false,
          ),
        )
        .toList(growable: false);

    await _repository.insertCategoriesIfMissing(categories);
  }
}

String templateCategoryId({
  required String budgetId,
  required String templateCode,
}) {
  return '$budgetId:template:$templateCode';
}

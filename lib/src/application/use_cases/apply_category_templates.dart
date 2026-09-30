import '../../domain/models/budget_category.dart';
import '../../domain/repositories/category_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';

final class ApplyCategoryTemplates {
  const ApplyCategoryTemplates({
    required CategoryRepository repository,
    required BudgetAuthorizationGuard authorization,
  }) : _repository = repository,
       _authorization = authorization;

  final CategoryRepository _repository;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call(String budgetId) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

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

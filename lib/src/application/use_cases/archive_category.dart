import '../../domain/repositories/category_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';

final class ArchiveCategory {
  const ArchiveCategory({
    required CategoryRepository repository,
    required BudgetAuthorizationGuard authorization,
  }) : _repository = repository,
       _authorization = authorization;

  final CategoryRepository _repository;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String categoryId,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );
    return _repository.setCategoryArchived(
      budgetId: budgetId,
      categoryId: categoryId,
      isArchived: true,
    );
  }
}

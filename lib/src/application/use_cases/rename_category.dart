import '../../domain/repositories/category_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/category_error.dart';

final class RenameCategory {
  const RenameCategory({
    required CategoryRepository repository,
    required BudgetAuthorizationGuard authorization,
  }) : _repository = repository,
       _authorization = authorization;

  final CategoryRepository _repository;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String categoryId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const CategoryError(
        code: CategoryErrorCode.emptyName,
        message: 'Название категории не может быть пустым.',
      );
    }

    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    return _repository.renameCategory(
      categoryId: categoryId,
      name: normalizedName,
    );
  }
}

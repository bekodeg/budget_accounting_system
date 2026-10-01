import '../../domain/models/budget_category.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/category_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/category_error.dart';
import '../ports/id_generator.dart';

final class CreateCategory {
  const CreateCategory({
    required CategoryRepository categoryRepository,
    required IdGenerator idGenerator,
    required BudgetAuthorizationGuard authorization,
  }) : _categoryRepository = categoryRepository,
       _idGenerator = idGenerator,
       _authorization = authorization;

  final CategoryRepository _categoryRepository;
  final IdGenerator _idGenerator;
  final BudgetAuthorizationGuard _authorization;

  Future<BudgetCategory> call({
    required String budgetId,
    required String name,
    required CategoryKind kind,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const CategoryError(
        code: CategoryErrorCode.emptyName,
        message: 'Название категории не может быть пустым.',
      );
    }

    final category = BudgetCategory(
      id: _idGenerator.nextId(),
      budgetId: budgetId,
      name: normalizedName,
      kind: kind,
      isArchived: false,
    );

    await _categoryRepository.createCategory(category);
    return category;
  }
}

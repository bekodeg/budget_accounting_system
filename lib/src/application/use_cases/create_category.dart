import '../../domain/models/budget_category.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/category_repository.dart';
import '../errors/category_error.dart';
import '../ports/id_generator.dart';

final class CreateCategory {
  const CreateCategory({
    required CategoryRepository categoryRepository,
    required IdGenerator idGenerator,
  })  : _categoryRepository = categoryRepository,
        _idGenerator = idGenerator;

  final CategoryRepository _categoryRepository;
  final IdGenerator _idGenerator;

  Future<BudgetCategory> call({
    required String budgetId,
    required String name,
    required CategoryKind kind,
  }) async {
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

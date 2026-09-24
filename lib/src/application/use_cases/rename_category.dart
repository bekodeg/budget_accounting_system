import '../../domain/repositories/category_repository.dart';
import '../errors/category_error.dart';

final class RenameCategory {
  const RenameCategory(this._repository);

  final CategoryRepository _repository;

  Future<void> call({required String categoryId, required String name}) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const CategoryError(
        code: CategoryErrorCode.emptyName,
        message: 'Название категории не может быть пустым.',
      );
    }

    return _repository.renameCategory(
      categoryId: categoryId,
      name: normalizedName,
    );
  }
}

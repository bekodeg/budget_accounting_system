import '../../domain/repositories/category_repository.dart';

final class ArchiveCategory {
  const ArchiveCategory(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String categoryId) {
    return _repository.setCategoryArchived(
      categoryId: categoryId,
      isArchived: true,
    );
  }
}

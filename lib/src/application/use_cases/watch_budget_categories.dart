import '../../domain/models/budget_category.dart';
import '../../domain/repositories/category_repository.dart';

final class WatchBudgetCategories {
  const WatchBudgetCategories(this._repository);

  final CategoryRepository _repository;

  Stream<List<BudgetCategory>> call(
    String budgetId, {
    bool includeArchived = false,
  }) {
    return _repository.watchCategories(
      budgetId,
      includeArchived: includeArchived,
    );
  }
}

import '../../domain/models/budget_category.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/repositories/category_repository.dart';
import '../errors/transaction_error.dart';

final class RequireCategoryInBudget {
  const RequireCategoryInBudget(this._repository);

  final CategoryRepository _repository;

  Future<BudgetCategory> call({
    required String budgetId,
    required String categoryId,
    required TransactionType transactionType,
    bool requireActive = true,
  }) async {
    final category = await _repository.findCategory(
      budgetId: budgetId,
      categoryId: categoryId,
    );

    if (category == null || (requireActive && category.isArchived)) {
      throw const TransactionError(
        code: TransactionErrorCode.invalidCategory,
        message: 'Категория недоступна в активном бюджете.',
      );
    }

    final matchesType = switch (transactionType) {
      TransactionType.income =>
        category.kind == CategoryKind.income ||
            category.kind == CategoryKind.both,
      TransactionType.expense =>
        category.kind == CategoryKind.expense ||
            category.kind == CategoryKind.both,
      TransactionType.transfer => true,
    };

    if (!matchesType) {
      throw const TransactionError(
        code: TransactionErrorCode.invalidCategory,
        message: 'Тип категории не соответствует типу операции.',
      );
    }

    return category;
  }
}

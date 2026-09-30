import '../../application/ports/sync_mutation_context_provider.dart';
import '../../application/ports/sync_mutation_executor.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/category_template.dart';
import '../../domain/models/sync_mutation.dart';
import '../../domain/repositories/category_repository.dart';

final class SyncingCategoryRepository implements CategoryRepository {
  const SyncingCategoryRepository({
    required CategoryRepository delegate,
    required SyncMutationExecutor executor,
    required SyncMutationContextProvider contextProvider,
  }) : _delegate = delegate,
       _executor = executor,
       _contextProvider = contextProvider;

  final CategoryRepository _delegate;
  final SyncMutationExecutor _executor;
  final SyncMutationContextProvider _contextProvider;

  @override
  Stream<List<BudgetCategory>> watchCategories(
    String budgetId, {
    required bool includeArchived,
  }) =>
      _delegate.watchCategories(budgetId, includeArchived: includeArchived);

  @override
  Future<BudgetCategory?> findCategory({
    required String budgetId,
    required String categoryId,
  }) =>
      _delegate.findCategory(budgetId: budgetId, categoryId: categoryId);

  @override
  Future<List<CategoryTemplate>> getTemplates() => _delegate.getTemplates();

  @override
  Future<void> insertCategoriesIfMissing(List<BudgetCategory> categories) async {
    for (final category in categories) {
      final existing = await _delegate.findCategory(
        budgetId: category.budgetId,
        categoryId: category.id,
      );
      if (existing == null) {
        await createCategory(category);
      }
    }
  }

  @override
  Future<void> createCategory(BudgetCategory category) async {
    final context = await _contextProvider.current();
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: category.budgetId,
          entityType: 'category',
          entityId: category.id,
          type: SyncMutationType.create,
          patch: _categoryPatch(category),
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.createCategory(category),
    );
  }

  @override
  Future<void> renameCategory({
    required String budgetId,
    required String categoryId,
    required String name,
  }) async {
    final context = await _contextProvider.current();
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: budgetId,
          entityType: 'category',
          entityId: categoryId,
          type: SyncMutationType.patch,
          patch: {'name': name},
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.renameCategory(
        budgetId: budgetId,
        categoryId: categoryId,
        name: name,
      ),
    );
  }

  @override
  Future<void> setCategoryArchived({
    required String budgetId,
    required String categoryId,
    required bool isArchived,
  }) async {
    final context = await _contextProvider.current();
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: budgetId,
          entityType: 'category',
          entityId: categoryId,
          type: SyncMutationType.patch,
          patch: {'is_archived': isArchived},
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.setCategoryArchived(
        budgetId: budgetId,
        categoryId: categoryId,
        isArchived: isArchived,
      ),
    );
  }
}

Map<String, Object?> _categoryPatch(BudgetCategory value) => {
  'name': value.name,
  'kind': value.kind.name.toUpperCase(),
  'is_archived': value.isArchived,
};

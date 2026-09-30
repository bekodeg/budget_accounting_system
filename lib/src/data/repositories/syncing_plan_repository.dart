import '../../application/ports/sync_mutation_context_provider.dart';
import '../../application/ports/sync_mutation_executor.dart';
import '../../domain/models/monthly_plan.dart';
import '../../domain/models/sync_mutation.dart';
import '../../domain/repositories/plan_repository.dart';

final class SyncingPlanRepository implements PlanRepository {
  const SyncingPlanRepository({
    required PlanRepository delegate,
    required SyncMutationExecutor executor,
    required SyncMutationContextProvider contextProvider,
  }) : _delegate = delegate,
       _executor = executor,
       _contextProvider = contextProvider;

  final PlanRepository _delegate;
  final SyncMutationExecutor _executor;
  final SyncMutationContextProvider _contextProvider;

  @override
  Stream<List<MonthlyPlan>> watchMonth({
    required String budgetId,
    required DateTime month,
  }) =>
      _delegate.watchMonth(budgetId: budgetId, month: month);

  @override
  Future<void> upsert(MonthlyPlan plan) async {
    final context = await _contextProvider.current();
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: plan.budgetId,
          entityType: 'plan',
          entityId: plan.id,
          type: SyncMutationType.patch,
          patch: {
            'month': plan.month,
            'category_id': plan.categoryId,
            'planned_amount_minor': plan.plannedAmountMinor,
            'updated_at': plan.updatedAt,
          },
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.upsert(plan),
    );
  }

  @override
  Future<void> clear({
    required String budgetId,
    required DateTime month,
    required String categoryId,
  }) async {
    final context = await _contextProvider.current();
    final entityId =
        '$budgetId:${month.year}-${month.month}:$categoryId';
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: budgetId,
          entityType: 'plan',
          entityId: entityId,
          type: SyncMutationType.delete,
          patch: {
            'month': normalizePlanMonth(month),
            'category_id': categoryId,
          },
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.clear(
        budgetId: budgetId,
        month: month,
        categoryId: categoryId,
      ),
    );
  }
}

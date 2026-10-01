import '../../application/ports/sync_mutation_context_provider.dart';
import '../../application/ports/sync_mutation_executor.dart';
import '../../domain/models/account_balance.dart';
import '../../domain/models/budget_account.dart';
import '../../domain/models/sync_mutation.dart';
import '../../domain/repositories/account_repository.dart';

final class SyncingAccountRepository implements AccountRepository {
  const SyncingAccountRepository({
    required AccountRepository delegate,
    required SyncMutationExecutor executor,
    required SyncMutationContextProvider contextProvider,
  }) : _delegate = delegate,
       _executor = executor,
       _contextProvider = contextProvider;

  final AccountRepository _delegate;
  final SyncMutationExecutor _executor;
  final SyncMutationContextProvider _contextProvider;

  @override
  Stream<List<BudgetAccount>> watchAccounts(
    String budgetId, {
    required bool includeArchived,
  }) =>
      _delegate.watchAccounts(budgetId, includeArchived: includeArchived);

  @override
  Future<BudgetAccount?> findAccount({
    required String budgetId,
    required String accountId,
  }) =>
      _delegate.findAccount(budgetId: budgetId, accountId: accountId);

  @override
  Future<bool> hasTransactions({
    required String budgetId,
    required String accountId,
  }) =>
      _delegate.hasTransactions(budgetId: budgetId, accountId: accountId);

  @override
  Future<void> createAccount(BudgetAccount account) async {
    final context = await _contextProvider.current();
    await _executor.execute<void>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: account.budgetId,
          entityType: 'account',
          entityId: account.id,
          type: SyncMutationType.create,
          patch: _accountPatch(account),
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.createAccount(account),
    );
  }

  @override
  Future<bool> updateAccount(BudgetAccount account) async {
    final context = await _contextProvider.current();
    return _executor.execute<bool>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: account.budgetId,
          entityType: 'account',
          entityId: account.id,
          type: SyncMutationType.patch,
          patch: _accountPatch(account),
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.updateAccount(account),
      shouldRecord: (changed) => changed,
    );
  }

  @override
  Future<bool> setAccountArchived({
    required String budgetId,
    required String accountId,
    required bool isArchived,
  }) async {
    final context = await _contextProvider.current();
    return _executor.execute<bool>(
      draft: SyncMutationDraft(
        spec: SyncMutationSpec(
          budgetId: budgetId,
          entityType: 'account',
          entityId: accountId,
          type: SyncMutationType.patch,
          patch: {'is_archived': isArchived},
        ),
        authorId: context.userId,
        deviceId: context.identity.deviceId,
      ),
      mutate: () => _delegate.setAccountArchived(
        budgetId: budgetId,
        accountId: accountId,
        isArchived: isArchived,
      ),
      shouldRecord: (changed) => changed,
    );
  }

  @override
  Future<AccountBalance?> getBalance({
    required String budgetId,
    required String accountId,
    DateTime? atInclusive,
  }) =>
      _delegate.getBalance(
        budgetId: budgetId,
        accountId: accountId,
        atInclusive: atInclusive,
      );

  @override
  Future<List<AccountBalance>> getBalances({
    required String budgetId,
    required bool includeArchived,
    DateTime? atInclusive,
  }) =>
      _delegate.getBalances(
        budgetId: budgetId,
        includeArchived: includeArchived,
        atInclusive: atInclusive,
      );
}

Map<String, Object?> _accountPatch(BudgetAccount value) => {
  'name': value.name,
  'opening_balance_minor': value.openingBalanceMinor,
  'currency': value.currency.code,
  'is_archived': value.isArchived,
};

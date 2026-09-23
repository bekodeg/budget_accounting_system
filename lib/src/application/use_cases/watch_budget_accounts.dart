import '../../domain/models/budget_account.dart';
import '../../domain/repositories/account_repository.dart';

final class WatchBudgetAccounts {
  const WatchBudgetAccounts(this._repository);

  final AccountRepository _repository;

  Stream<List<BudgetAccount>> call(
    String budgetId, {
    bool includeArchived = false,
  }) {
    return _repository.watchAccounts(
      budgetId,
      includeArchived: includeArchived,
    );
  }
}

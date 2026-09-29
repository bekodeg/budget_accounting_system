import '../../domain/models/account_balance.dart';
import '../../domain/repositories/account_repository.dart';

final class GetBudgetAccountBalances {
  const GetBudgetAccountBalances(this._repository);

  final AccountRepository _repository;

  Future<List<AccountBalance>> call({
    required String budgetId,
    bool includeArchived = false,
    DateTime? atInclusive,
  }) {
    return _repository.getBalances(
      budgetId: budgetId,
      includeArchived: includeArchived,
      atInclusive: atInclusive,
    );
  }
}

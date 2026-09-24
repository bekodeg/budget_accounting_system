import '../../domain/models/budget_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../errors/account_error.dart';

final class RequireAccountInBudget {
  const RequireAccountInBudget(this._repository);

  final AccountRepository _repository;

  Future<BudgetAccount> call({
    required String budgetId,
    required String accountId,
    bool requireActive = true,
  }) async {
    final account = await _repository.findAccount(
      budgetId: budgetId,
      accountId: accountId,
    );

    if (account == null || (requireActive && account.isArchived)) {
      throw const AccountError(
        code: AccountErrorCode.accountNotFound,
        message: 'Счет не найден среди активных счетов бюджета.',
      );
    }

    return account;
  }
}

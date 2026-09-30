import '../../domain/repositories/account_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../errors/account_error.dart';

final class ArchiveAccount {
  const ArchiveAccount({
    required AccountRepository repository,
    required BudgetAuthorizationGuard authorization,
  }) : _repository = repository,
       _authorization = authorization;

  final AccountRepository _repository;
  final BudgetAuthorizationGuard _authorization;

  Future<void> call({
    required String budgetId,
    required String accountId,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    final updated = await _repository.setAccountArchived(
      budgetId: budgetId,
      accountId: accountId,
      isArchived: true,
    );

    if (!updated) {
      throw const AccountError(
        code: AccountErrorCode.accountNotFound,
        message: 'Счет не найден в активном бюджете.',
      );
    }
  }
}

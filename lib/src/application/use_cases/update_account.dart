import '../../domain/models/budget_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../errors/account_error.dart';

final class UpdateAccount {
  const UpdateAccount(this._repository);

  final AccountRepository _repository;

  Future<BudgetAccount> call({
    required String budgetId,
    required String accountId,
    required String name,
    required Currency currency,
    required BigInt openingBalanceMinor,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const AccountError(
        code: AccountErrorCode.emptyName,
        message: 'Название счета не может быть пустым.',
      );
    }

    final current = await _repository.findAccount(
      budgetId: budgetId,
      accountId: accountId,
    );
    if (current == null) {
      throw const AccountError(
        code: AccountErrorCode.accountNotFound,
        message: 'Счет не найден в активном бюджете.',
      );
    }

    if (current.currency != currency &&
        await _repository.hasTransactions(
          budgetId: budgetId,
          accountId: accountId,
        )) {
      throw const AccountError(
        code: AccountErrorCode.currencyLockedByTransactions,
        message: 'Нельзя менять валюту счета после появления операций.',
      );
    }

    final updated = current.copyWith(
      name: normalizedName,
      currency: currency,
      openingBalanceMinor: openingBalanceMinor,
    );
    final didUpdate = await _repository.updateAccount(updated);
    if (!didUpdate) {
      throw const AccountError(
        code: AccountErrorCode.accountNotFound,
        message: 'Счет не найден в активном бюджете.',
      );
    }

    return updated;
  }
}

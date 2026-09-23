import '../../domain/models/account_balance.dart';
import '../../domain/repositories/account_repository.dart';
import '../errors/account_error.dart';

final class GetAccountBalance {
  const GetAccountBalance(this._repository);

  final AccountRepository _repository;

  Future<AccountBalance> call({
    required String budgetId,
    required String accountId,
  }) async {
    final balance = await _repository.getBalance(
      budgetId: budgetId,
      accountId: accountId,
    );
    if (balance == null) {
      throw const AccountError(
        code: AccountErrorCode.accountNotFound,
        message: 'Счет не найден в активном бюджете.',
      );
    }

    return balance;
  }
}

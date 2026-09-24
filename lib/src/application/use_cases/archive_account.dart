import '../../domain/repositories/account_repository.dart';
import '../errors/account_error.dart';

final class ArchiveAccount {
  const ArchiveAccount(this._repository);

  final AccountRepository _repository;

  Future<void> call({
    required String budgetId,
    required String accountId,
  }) async {
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

import '../../domain/models/budget_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../errors/account_error.dart';
import '../ports/id_generator.dart';

final class CreateAccount {
  const CreateAccount({
    required AccountRepository accountRepository,
    required IdGenerator idGenerator,
  })  : _accountRepository = accountRepository,
        _idGenerator = idGenerator;

  final AccountRepository _accountRepository;
  final IdGenerator _idGenerator;

  Future<BudgetAccount> call({
    required String budgetId,
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

    final account = BudgetAccount(
      id: _idGenerator.nextId(),
      budgetId: budgetId,
      name: normalizedName,
      openingBalanceMinor: openingBalanceMinor,
      currency: currency,
      isArchived: false,
    );

    await _accountRepository.createAccount(account);
    return account;
  }
}

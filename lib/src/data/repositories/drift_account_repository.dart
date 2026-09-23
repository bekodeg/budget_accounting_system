import '../../domain/models/account_balance.dart';
import '../../domain/models/budget_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../dal/category_account_dao.dart';
import '../database/app_database.dart';

final class DriftAccountRepository implements AccountRepository {
  const DriftAccountRepository(this._dao);

  final CategoryAccountDao _dao;

  @override
  Stream<List<BudgetAccount>> watchAccounts(
    String budgetId, {
    required bool includeArchived,
  }) {
    return _dao
        .watchAccounts(
          budgetId,
          includeArchived: includeArchived,
        )
        .map(
          (accounts) => accounts
              .map(_toDomainAccount)
              .toList(growable: false),
        );
  }

  @override
  Future<BudgetAccount?> findAccount({
    required String budgetId,
    required String accountId,
  }) async {
    final account = await _dao.findAccount(
      budgetId: budgetId,
      accountId: accountId,
    );
    return account == null ? null : _toDomainAccount(account);
  }

  @override
  Future<bool> hasTransactions({
    required String budgetId,
    required String accountId,
  }) {
    return _dao.accountHasTransactions(
      budgetId: budgetId,
      accountId: accountId,
    );
  }

  @override
  Future<void> createAccount(BudgetAccount account) {
    return _dao.createAccount(
      AccountsCompanion.insert(
        id: account.id,
        budgetId: account.budgetId,
        name: account.name,
        openingBalanceMinor: Value(account.openingBalanceMinor),
        currency: account.currency.code,
        isArchived: Value(account.isArchived),
      ),
    );
  }

  @override
  Future<bool> updateAccount(BudgetAccount account) async {
    final updated = await _dao.updateAccount(
      budgetId: account.budgetId,
      accountId: account.id,
      name: account.name,
      currency: account.currency.code,
      openingBalanceMinor: account.openingBalanceMinor,
    );
    return updated == 1;
  }

  @override
  Future<bool> setAccountArchived({
    required String budgetId,
    required String accountId,
    required bool isArchived,
  }) async {
    final updated = await _dao.setAccountArchived(
      budgetId: budgetId,
      accountId: accountId,
      isArchived: isArchived,
    );
    return updated == 1;
  }

  @override
  Future<AccountBalance?> getBalance({
    required String budgetId,
    required String accountId,
  }) async {
    final account = await _dao.findAccount(
      budgetId: budgetId,
      accountId: accountId,
    );
    if (account == null) {
      return null;
    }

    final balance = await _dao.getAccountBalanceMinor(
      budgetId: budgetId,
      accountId: accountId,
      openingBalanceMinor: account.openingBalanceMinor,
    );

    return AccountBalance(
      accountId: account.id,
      minorUnits: balance,
      currency: Currency(account.currency),
    );
  }

  BudgetAccount _toDomainAccount(Account account) {
    return BudgetAccount(
      id: account.id,
      budgetId: account.budgetId,
      name: account.name,
      openingBalanceMinor: account.openingBalanceMinor,
      currency: Currency(account.currency),
      isArchived: account.isArchived,
    );
  }
}

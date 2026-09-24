import '../models/account_balance.dart';
import '../models/budget_account.dart';

abstract interface class AccountRepository {
  Stream<List<BudgetAccount>> watchAccounts(
    String budgetId, {
    required bool includeArchived,
  });

  Future<BudgetAccount?> findAccount({
    required String budgetId,
    required String accountId,
  });

  Future<bool> hasTransactions({
    required String budgetId,
    required String accountId,
  });

  Future<void> createAccount(BudgetAccount account);

  Future<bool> updateAccount(BudgetAccount account);

  Future<bool> setAccountArchived({
    required String budgetId,
    required String accountId,
    required bool isArchived,
  });

  Future<AccountBalance?> getBalance({
    required String budgetId,
    required String accountId,
  });
}

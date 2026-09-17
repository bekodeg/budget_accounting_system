import '../database/app_database.dart';
import 'category_account_dao.dart';
import 'plan_receipt_dao.dart';
import 'report_dao.dart';
import 'sync_dao.dart';
import 'transaction_dao.dart';
import 'user_budget_dao.dart';

export '../database/app_database.dart';
export 'category_account_dao.dart';
export 'plan_receipt_dao.dart';
export 'report_dao.dart';
export 'sync_dao.dart';
export 'transaction_dao.dart';
export 'user_budget_dao.dart';

final class BudgetDal {
  BudgetDal(this.database)
      : usersAndBudgets = UserBudgetDao(database),
        categoriesAndAccounts = CategoryAccountDao(database),
        transactions = TransactionDao(database),
        plansAndReceipts = PlanReceiptDao(database),
        reports = ReportDao(database),
        sync = SyncDao(database);

  factory BudgetDal.defaults() => BudgetDal(AppDatabase.defaults());

  final AppDatabase database;
  final UserBudgetDao usersAndBudgets;
  final CategoryAccountDao categoriesAndAccounts;
  final TransactionDao transactions;
  final PlanReceiptDao plansAndReceipts;
  final ReportDao reports;
  final SyncDao sync;

  Future<void> close() => database.close();
}

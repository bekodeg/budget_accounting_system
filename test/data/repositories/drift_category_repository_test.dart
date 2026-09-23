import 'package:budget_accounting_system/src/application/use_cases/apply_category_templates.dart';
import 'package:budget_accounting_system/src/data/dal/category_account_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_category_repository.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao userBudgetDao;
  late CategoryAccountDao categoryDao;
  late TransactionDao transactionDao;
  late DriftCategoryRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    userBudgetDao = UserBudgetDao(database);
    categoryDao = CategoryAccountDao(database);
    transactionDao = TransactionDao(database);
    repository = DriftCategoryRepository(categoryDao);

    await userBudgetDao.upsertUser(
      UsersCompanion.insert(
        id: 'user-1',
        name: 'Alice',
        publicKey: 'public-key',
      ),
    );
    await userBudgetDao.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Household',
        baseCurrency: 'EUR',
        createdBy: 'user-1',
      ),
    );
    await userBudgetDao.upsertMember(
      BudgetMembersCompanion.insert(
        budgetId: 'budget-1',
        userId: 'user-1',
        role: 'OWNER',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('returns seeded templates in stable order', () async {
    final templates = await repository.getTemplates();

    expect(templates, isNotEmpty);
    for (var index = 1; index < templates.length; index++) {
      final previous = templates[index - 1];
      final current = templates[index];

      final previousKey =
          '${previous.kind.name}:${previous.sortOrder.toString().padLeft(4, '0')}:${previous.code}';
      final currentKey =
          '${current.kind.name}:${current.sortOrder.toString().padLeft(4, '0')}:${current.code}';
      expect(previousKey.compareTo(currentKey) <= 0, isTrue);
    }
  });

  test('reapplying templates does not duplicate categories', () async {
    final applyTemplates = ApplyCategoryTemplates(repository);
    final templateCount = (await repository.getTemplates()).length;

    await applyTemplates('budget-1');
    await applyTemplates('budget-1');

    final categories = await repository
        .watchCategories('budget-1', includeArchived: true)
        .first;

    expect(categories, hasLength(templateCount));
  });

  test('active and full lists stay stable across rename and archive', () async {
    await repository.createCategory(
      const BudgetCategory(
        id: 'expense-2',
        budgetId: 'budget-1',
        name: 'Транспорт',
        kind: CategoryKind.expense,
        isArchived: false,
      ),
    );
    await repository.createCategory(
      const BudgetCategory(
        id: 'expense-1',
        budgetId: 'budget-1',
        name: 'Еда',
        kind: CategoryKind.expense,
        isArchived: false,
      ),
    );
    await repository.createCategory(
      const BudgetCategory(
        id: 'income-1',
        budgetId: 'budget-1',
        name: 'Зарплата',
        kind: CategoryKind.income,
        isArchived: false,
      ),
    );

    final beforeArchive = await repository
        .watchCategories('budget-1', includeArchived: false)
        .first;
    expect(
      beforeArchive.map((category) => category.id).toList(),
      ['expense-1', 'expense-2', 'income-1'],
    );

    await repository.renameCategory(
      categoryId: 'expense-1',
      name: 'Продукты',
    );
    await repository.setCategoryArchived(
      categoryId: 'expense-1',
      isArchived: true,
    );

    final active = await repository
        .watchCategories('budget-1', includeArchived: false)
        .first;
    final all = await repository
        .watchCategories('budget-1', includeArchived: true)
        .first;

    expect(active.map((category) => category.id), isNot(contains('expense-1')));
    final archived = all.singleWhere(
      (category) => category.id == 'expense-1',
    );
    expect(archived.name, 'Продукты');
    expect(archived.isArchived, isTrue);
  });

  test('archiving category preserves transaction history', () async {
    await repository.createCategory(
      const BudgetCategory(
        id: 'category-1',
        budgetId: 'budget-1',
        name: 'Продукты',
        kind: CategoryKind.expense,
        isArchived: false,
      ),
    );
    await categoryDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'account-1',
        budgetId: 'budget-1',
        name: 'Карта',
        currency: 'EUR',
      ),
    );
    await transactionDao.upsert(
      BudgetTransactionsCompanion.insert(
        id: 'transaction-1',
        budgetId: 'budget-1',
        occurredAt: DateTime(2026, 9, 23),
        amountMinor: BigInt.from(2500),
        currency: 'EUR',
        type: 'EXPENSE',
        authorId: 'user-1',
        accountId: 'account-1',
        categoryId: const Value('category-1'),
      ),
    );

    await repository.setCategoryArchived(
      categoryId: 'category-1',
      isArchived: true,
    );

    final transaction = await transactionDao.findById('transaction-1');
    final allCategories = await repository
        .watchCategories('budget-1', includeArchived: true)
        .first;

    expect(transaction?.categoryId, 'category-1');
    expect(
      allCategories.singleWhere((category) => category.id == 'category-1').name,
      'Продукты',
    );
  });
}

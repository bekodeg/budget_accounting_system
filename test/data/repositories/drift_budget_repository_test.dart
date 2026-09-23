import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_budget_repository.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao dao;
  late DriftBudgetRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dao = UserBudgetDao(database);
    repository = DriftBudgetRepository(dao);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'maps Drift budgets to domain summaries for active membership',
    () async {
      await dao.upsertUser(
        UsersCompanion.insert(
          id: 'user-1',
          name: 'Alice',
          publicKey: 'public-key',
        ),
      );
      await dao.upsertBudget(
        BudgetsCompanion.insert(
          id: 'budget-1',
          name: 'Household',
          baseCurrency: 'EUR',
          createdBy: 'user-1',
        ),
      );
      await dao.upsertMember(
        BudgetMembersCompanion.insert(
          budgetId: 'budget-1',
          userId: 'user-1',
          role: 'OWNER',
        ),
      );

      final budgets = await repository.watchBudgetsForUser('user-1').first;

      expect(budgets, const [
        BudgetSummary(id: 'budget-1', name: 'Household', baseCurrency: 'EUR'),
      ]);
    },
  );

  test('does not expose revoked membership', () async {
    await dao.upsertUser(
      UsersCompanion.insert(
        id: 'user-1',
        name: 'Alice',
        publicKey: 'public-key',
      ),
    );
    await dao.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Household',
        baseCurrency: 'EUR',
        createdBy: 'user-1',
      ),
    );
    await dao.upsertMember(
      BudgetMembersCompanion.insert(
        budgetId: 'budget-1',
        userId: 'user-1',
        role: 'OWNER',
        revokedAt: Value(DateTime(2026, 9, 18)),
      ),
    );

    final budgets = await repository.watchBudgetsForUser('user-1').first;

    expect(budgets, isEmpty);
  });

  test('creates user budget and OWNER membership in one transaction', () async {
    final session = await repository.createOwnedBudget(
      userId: 'user-1',
      userName: 'Alice',
      publicKey: 'local-unverified:user-1',
      budgetId: 'budget-1',
      budgetName: 'Household',
      baseCurrency: Currency('EUR'),
    );

    final user = await dao.findUserById('user-1');
    final memberships = await dao.getMembers('budget-1');
    final budgets = await repository.getBudgetsForUser('user-1');

    expect(session.userId, 'user-1');
    expect(user?.name, 'Alice');
    expect(memberships, hasLength(1));
    expect(memberships.single.role, 'OWNER');
    expect(budgets, const [
      BudgetSummary(id: 'budget-1', name: 'Household', baseCurrency: 'EUR'),
    ]);
    expect(await repository.findFirstUserIdWithBudget(), 'user-1');
  });

  test('rolls back user when budget insert fails', () async {
    await dao.upsertUser(
      UsersCompanion.insert(
        id: 'existing-user',
        name: 'Existing',
        publicKey: 'existing-key',
      ),
    );
    await dao.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Existing budget',
        baseCurrency: 'EUR',
        createdBy: 'existing-user',
      ),
    );

    await expectLater(
      repository.createOwnedBudget(
        userId: 'user-2',
        userName: 'Bob',
        publicKey: 'local-unverified:user-2',
        budgetId: 'budget-1',
        budgetName: 'Duplicate',
        baseCurrency: Currency('EUR'),
      ),
      throwsA(anything),
    );

    expect(await dao.findUserById('user-2'), isNull);
  });
}

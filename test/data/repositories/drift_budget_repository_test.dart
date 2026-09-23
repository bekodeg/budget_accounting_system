import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_budget_repository.dart';
import 'package:budget_accounting_system/src/domain/models/budget_summary.dart';
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

  test('maps Drift budgets to domain summaries for active membership', () async {
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

    expect(
      budgets,
      const [
        BudgetSummary(
          id: 'budget-1',
          name: 'Household',
          baseCurrency: 'EUR',
        ),
      ],
    );
  });

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
}

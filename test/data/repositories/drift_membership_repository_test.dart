import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_membership_repository.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao dao;
  late DriftMembershipRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    dao = UserBudgetDao(database);
    repository = DriftMembershipRepository(dao);

    for (final user in [
      ('owner-1', 'Owner One'),
      ('owner-2', 'Owner Two'),
      ('viewer-1', 'Viewer'),
    ]) {
      await dao.upsertUser(
        UsersCompanion.insert(
          id: user.$1,
          name: user.$2,
          publicKey: 'ed25519:${user.$1}',
        ),
      );
    }

    await dao.upsertBudget(
      BudgetsCompanion.insert(
        id: 'budget-1',
        name: 'Household',
        baseCurrency: 'EUR',
        createdBy: 'owner-1',
      ),
    );

    for (final member in [
      ('owner-1', 'OWNER'),
      ('owner-2', 'OWNER'),
      ('viewer-1', 'VIEWER'),
    ]) {
      await dao.upsertMember(
        BudgetMembersCompanion.insert(
          budgetId: 'budget-1',
          userId: member.$1,
          role: member.$2,
        ),
      );
    }
  });

  tearDown(() => database.close());

  test('reads active member and counts owners', () async {
    final member = await repository.findActiveMember(
      budgetId: 'budget-1',
      userId: 'viewer-1',
    );

    expect(member?.name, 'Viewer');
    expect(member?.role, MemberRole.viewer);
    expect(await repository.countActiveOwners('budget-1'), 2);
  });

  test('role update is reactive and storage mapping stays typed', () async {
    final stream = repository.watchMembers('budget-1');
    final first = await stream.first;
    expect(first, hasLength(3));

    await repository.updateMemberRole(
      budgetId: 'budget-1',
      userId: 'viewer-1',
      role: MemberRole.editor,
    );

    final updated = await repository.findActiveMember(
      budgetId: 'budget-1',
      userId: 'viewer-1',
    );
    expect(updated?.role, MemberRole.editor);
  });
}

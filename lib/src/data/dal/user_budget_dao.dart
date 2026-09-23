import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class UserBudgetDao {
  UserBudgetDao(this._db);

  final AppDatabase _db;

  Future<void> upsertUser(UsersCompanion user) async {
    await _db.into(_db.users).insertOnConflictUpdate(user);
  }

  Future<User?> findUserById(String id) {
    return (_db.select(
      _db.users,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertBudget(BudgetsCompanion budget) async {
    await _db.into(_db.budgets).insertOnConflictUpdate(budget);
  }

  Future<void> upsertMember(BudgetMembersCompanion member) async {
    await _db.into(_db.budgetMembers).insertOnConflictUpdate(member);
  }

  Future<void> createOwnedBudget({
    required UsersCompanion user,
    required BudgetsCompanion budget,
    required BudgetMembersCompanion ownerMembership,
  }) {
    return _db.transaction(() async {
      await _db.into(_db.users).insert(user);
      await _db.into(_db.budgets).insert(budget);
      await _db.into(_db.budgetMembers).insert(ownerMembership);
    });
  }

  Future<String?> findFirstUserIdWithBudget() async {
    final query = _db.select(_db.budgetMembers)
      ..where((row) => row.revokedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.joinedAt)])
      ..limit(1);

    final membership = await query.getSingleOrNull();
    return membership?.userId;
  }

  Stream<List<Budget>> watchBudgetsForUser(String userId) {
    final query = _db.select(_db.budgets).join([
      innerJoin(
        _db.budgetMembers,
        _db.budgetMembers.budgetId.equalsExp(_db.budgets.id),
      ),
    ])
      ..where(
        _db.budgetMembers.userId.equals(userId) &
            _db.budgetMembers.revokedAt.isNull(),
      )
      ..orderBy([OrderingTerm.asc(_db.budgets.createdAt)]);

    return query.watch().map(_readBudgets);
  }

  Future<List<Budget>> getBudgetsForUser(String userId) async {
    final query = _db.select(_db.budgets).join([
      innerJoin(
        _db.budgetMembers,
        _db.budgetMembers.budgetId.equalsExp(_db.budgets.id),
      ),
    ])
      ..where(
        _db.budgetMembers.userId.equals(userId) &
            _db.budgetMembers.revokedAt.isNull(),
      )
      ..orderBy([OrderingTerm.asc(_db.budgets.createdAt)]);

    final rows = await query.get();
    return _readBudgets(rows);
  }

  Future<List<BudgetMember>> getMembers(String budgetId) {
    return (_db.select(
      _db.budgetMembers,
    )..where((row) => row.budgetId.equals(budgetId))).get();
  }

  List<Budget> _readBudgets(List<TypedResult> rows) {
    return rows.map((row) => row.readTable(_db.budgets)).toList(growable: false);
  }
}

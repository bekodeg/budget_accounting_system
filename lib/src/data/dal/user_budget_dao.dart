import '../database/app_database.dart';

final class UserBudgetDao {
  UserBudgetDao(this._db);

  final AppDatabase _db;

  Future<void> upsertUser(UsersCompanion user) async {
    await _db.into(_db.users).insertOnConflictUpdate(user);
  }

  Future<User?> findUserById(String id) {
    return (_db.select(_db.users)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertBudget(BudgetsCompanion budget) async {
    await _db.into(_db.budgets).insertOnConflictUpdate(budget);
  }

  Future<void> upsertMember(BudgetMembersCompanion member) async {
    await _db.into(_db.budgetMembers).insertOnConflictUpdate(member);
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
      );

    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(_db.budgets)).toList(),
        );
  }

  Future<List<BudgetMember>> getMembers(String budgetId) {
    return (_db.select(_db.budgetMembers)
          ..where((row) => row.budgetId.equals(budgetId)))
        .get();
  }
}

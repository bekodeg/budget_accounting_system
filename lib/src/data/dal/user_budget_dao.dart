import 'package:drift/drift.dart';

import '../database/app_database.dart';

final class MembershipRow {
  const MembershipRow({required this.member, required this.user});

  final BudgetMember member;
  final User user;
}

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

  Future<Device?> findDeviceById(String id) {
    return (_db.select(
      _db.devices,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> migrateLegacyIdentity({
    required String userId,
    required String publicKey,
    required String deviceId,
  }) {
    return _db.transaction(() async {
      final user = await findUserById(userId);
      if (user == null) {
        throw StateError('Cannot migrate identity for missing user $userId.');
      }

      await (_db.update(_db.users)..where((row) => row.id.equals(userId)))
          .write(UsersCompanion(publicKey: Value(publicKey)));
      await _db
          .into(_db.devices)
          .insert(
            DevicesCompanion.insert(id: deviceId, userId: userId),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  Future<Budget?> findBudgetById(String id) {
    return (_db.select(
      _db.budgets,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertBudget(BudgetsCompanion budget) async {
    await _db.into(_db.budgets).insertOnConflictUpdate(budget);
  }

  Future<void> upsertMember(BudgetMembersCompanion member) async {
    await _db.into(_db.budgetMembers).insertOnConflictUpdate(member);
  }

  Future<void> acceptInvitation({
    required UsersCompanion owner,
    required DevicesCompanion ownerDevice,
    required BudgetsCompanion budget,
    required BudgetMembersCompanion ownerMembership,
    required BudgetMembersCompanion joiningMembership,
    required String joiningPublicKey,
    String? joiningUserName,
    DevicesCompanion? joiningDevice,
  }) {
    return _db.transaction(() async {
      final ownerId = owner.id.value;
      final existingOwner = await findUserById(ownerId);
      if (existingOwner == null) {
        await _db.into(_db.users).insert(owner);
      } else {
        final invitedPublicKey = owner.publicKey.value;
        if (existingOwner.publicKey != invitedPublicKey) {
          throw StateError('Owner public key conflicts with local identity.');
        }
      }

      final existingOwnerDevice = await findDeviceById(ownerDevice.id.value);
      if (existingOwnerDevice == null) {
        await _db.into(_db.devices).insert(ownerDevice);
      } else if (existingOwnerDevice.userId != ownerId) {
        throw StateError('Owner device conflicts with local identity.');
      }

      final joiningUserId = joiningMembership.userId.value;
      final joiningUser = await findUserById(joiningUserId);
      if (joiningUser == null) {
        final normalizedName = joiningUserName?.trim();
        if (normalizedName == null || normalizedName.isEmpty) {
          throw StateError('Joining user name is required for a new identity.');
        }
        await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: joiningUserId,
            name: normalizedName,
            publicKey: joiningPublicKey,
          ),
        );
        if (joiningDevice == null) {
          throw StateError('Joining device is required for a new identity.');
        }
        await _db.into(_db.devices).insert(joiningDevice);
      } else {
        if (joiningUser.publicKey != joiningPublicKey) {
          throw StateError('Joining identity conflicts with local user.');
        }
        if (joiningDevice != null) {
          final existingJoiningDevice = await findDeviceById(
            joiningDevice.id.value,
          );
          if (existingJoiningDevice == null) {
            await _db.into(_db.devices).insert(joiningDevice);
          } else if (existingJoiningDevice.userId != joiningUserId) {
            throw StateError('Joining device conflicts with local identity.');
          }
        }
      }

      final budgetId = budget.id.value;
      final existingBudget = await findBudgetById(budgetId);
      if (existingBudget == null) {
        await _db.into(_db.budgets).insert(budget);
      } else {
        if (existingBudget.createdBy != budget.createdBy.value ||
            existingBudget.name != budget.name.value ||
            existingBudget.baseCurrency != budget.baseCurrency.value) {
          throw StateError('Invite budget metadata conflicts with local data.');
        }
      }

      await _db.into(_db.budgetMembers).insertOnConflictUpdate(ownerMembership);
      await _db
          .into(_db.budgetMembers)
          .insertOnConflictUpdate(joiningMembership);
    });
  }

  Future<void> createOwnedBudget({
    required UsersCompanion user,
    required BudgetsCompanion budget,
    required BudgetMembersCompanion ownerMembership,
    required DevicesCompanion device,
    List<CategoriesCompanion> initialCategories = const [],
  }) {
    return _db.transaction(() async {
      await _db.into(_db.users).insert(user);
      await _db.into(_db.devices).insert(device);
      await _db.into(_db.budgets).insert(budget);
      await _db.into(_db.budgetMembers).insert(ownerMembership);

      for (final category in initialCategories) {
        await _db.into(_db.categories).insert(category);
      }
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
    final query =
        _db.select(_db.budgets).join([
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
    final query =
        _db.select(_db.budgets).join([
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

  Future<MembershipRow?> findActiveMember({
    required String budgetId,
    required String userId,
  }) async {
    final query =
        _db.select(_db.budgetMembers).join([
            innerJoin(
              _db.users,
              _db.users.id.equalsExp(_db.budgetMembers.userId),
            ),
          ])
          ..where(
            _db.budgetMembers.budgetId.equals(budgetId) &
                _db.budgetMembers.userId.equals(userId) &
                _db.budgetMembers.revokedAt.isNull(),
          )
          ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return MembershipRow(
      member: row.readTable(_db.budgetMembers),
      user: row.readTable(_db.users),
    );
  }

  Stream<List<MembershipRow>> watchActiveMembers(String budgetId) {
    final query =
        _db.select(_db.budgetMembers).join([
            innerJoin(
              _db.users,
              _db.users.id.equalsExp(_db.budgetMembers.userId),
            ),
          ])
          ..where(
            _db.budgetMembers.budgetId.equals(budgetId) &
                _db.budgetMembers.revokedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(_db.budgetMembers.joinedAt),
            OrderingTerm.asc(_db.budgetMembers.userId),
          ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MembershipRow(
              member: row.readTable(_db.budgetMembers),
              user: row.readTable(_db.users),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<int> countActiveOwners(String budgetId) async {
    final count = _db.budgetMembers.userId.count();
    final query = _db.selectOnly(_db.budgetMembers)
      ..addColumns([count])
      ..where(
        _db.budgetMembers.budgetId.equals(budgetId) &
            _db.budgetMembers.role.equals('OWNER') &
            _db.budgetMembers.revokedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<bool> updateMemberRole({
    required String budgetId,
    required String userId,
    required String role,
  }) async {
    final changed =
        await (_db.update(_db.budgetMembers)..where(
              (row) =>
                  row.budgetId.equals(budgetId) &
                  row.userId.equals(userId) &
                  row.revokedAt.isNull(),
            ))
            .write(BudgetMembersCompanion(role: Value(role)));
    return changed == 1;
  }

  List<Budget> _readBudgets(List<TypedResult> rows) {
    return rows
        .map((row) => row.readTable(_db.budgets))
        .toList(growable: false);
  }
}

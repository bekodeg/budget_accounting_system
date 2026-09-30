import 'package:budget_accounting_system/src/data/dal/user_budget_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_identity_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserBudgetDao dao;
  late DriftIdentityRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    dao = UserBudgetDao(database);
    repository = DriftIdentityRepository(dao);

    await dao.upsertUser(
      UsersCompanion.insert(
        id: 'user-1',
        name: 'Alice',
        publicKey: 'local-unverified:user-1',
      ),
    );
  });

  tearDown(() => database.close());

  test('migrates legacy public identity and creates active device', () async {
    await repository.migrateLegacyIdentity(
      userId: 'user-1',
      publicKey: 'ed25519:public-key',
      deviceId: 'device-1',
    );

    expect(await repository.getUserPublicKey('user-1'), 'ed25519:public-key');
    final device = await repository.findDevice('device-1');
    expect(device?.userId, 'user-1');
    expect(device?.isRevoked, isFalse);
  });

  test('ordinary Drift tables contain no private key column', () async {
    final tables = ['users', 'devices', 'sync_operations'];

    for (final table in tables) {
      final columns = await database
          .customSelect('PRAGMA table_info($table)')
          .get();
      final names = columns
          .map((row) => row.read<String>('name').toLowerCase())
          .toList();

      expect(
        names.where((name) => name.contains('private')),
        isEmpty,
        reason: '$table must not persist private key material',
      );
    }
  });
}

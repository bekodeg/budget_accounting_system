import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('schema v1 snapshot matches the current database schema', () async {
    final connection = await verifier.startAt(1);
    final database = AppDatabase(connection);

    await verifier.migrateAndValidate(database, 1);
    await database.close();
  });

  test('schema v1 preserves representative data', () async {
    final schema = await verifier.schemaAt(1);

    final oldDatabase = v1.DatabaseAtV1(schema.newConnection());
    await oldDatabase
        .into(oldDatabase.users)
        .insert(
          v1.UsersCompanion.insert(
            id: 'u1',
            name: 'Snapshot User',
            publicKey: 'snapshot-key',
          ),
        );
    await oldDatabase
        .into(oldDatabase.budgets)
        .insert(
          v1.BudgetsCompanion.insert(
            id: 'b1',
            name: 'Snapshot Budget',
            baseCurrency: 'EUR',
            createdBy: 'u1',
          ),
        );
    await oldDatabase.close();

    final database = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(database, 1);
    await database.close();

    final verifiedDatabase = v1.DatabaseAtV1(schema.newConnection());
    final user = await (verifiedDatabase.select(
      verifiedDatabase.users,
    )..where((row) => row.id.equals('u1'))).getSingle();
    final budget = await (verifiedDatabase.select(
      verifiedDatabase.budgets,
    )..where((row) => row.id.equals('b1'))).getSingle();

    expect(user.name, 'Snapshot User');
    expect(budget.name, 'Snapshot Budget');
    expect(budget.baseCurrency, 'EUR');

    await verifiedDatabase.close();
  });
}

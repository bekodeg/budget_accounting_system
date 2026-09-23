import 'package:flutter_test/flutter_test.dart';

import '../../support/drift_snapshot_harness.dart';

void main() {
  const snapshotPath =
      'drift_schemas/app_database/drift_schema_v1.json';

  test('saved schema v1 can be opened by the current database', () async {
    final database = const DriftSnapshotHarness(snapshotPath).openCurrent(
      setupSql: const [
        "INSERT INTO users (id, name, public_key) "
            "VALUES ('u1', 'Snapshot User', 'snapshot-key')",
        "INSERT INTO budgets (id, name, base_currency, created_by) "
            "VALUES ('b1', 'Snapshot Budget', 'EUR', 'u1')",
      ],
    );
    addTearDown(database.close);

    final user = await (database.select(database.users)
          ..where((row) => row.id.equals('u1')))
        .getSingle();
    final budget = await (database.select(database.budgets)
          ..where((row) => row.id.equals('b1')))
        .getSingle();

    expect(database.schemaVersion, greaterThanOrEqualTo(1));
    expect(user.name, 'Snapshot User');
    expect(budget.name, 'Snapshot Budget');
    expect(budget.baseCurrency, 'EUR');
  });

  test('saved schema v1 contains the expected core tables', () async {
    final database = const DriftSnapshotHarness(snapshotPath).openCurrent();
    addTearDown(database.close);

    final rows = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();

    final names = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      names,
      containsAll(<String>{
        'users',
        'budgets',
        'budget_members',
        'categories',
        'accounts',
        'transactions',
        'plans',
        'receipts',
        'devices',
        'sync_operations',
        'category_templates',
      }),
    );
  });
}

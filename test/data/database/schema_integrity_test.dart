import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('schema v1 contains required transaction and sync indexes', () async {
    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();

    final indexNames = rows
        .map((row) => row.read<String>('name'))
        .where((name) => !name.startsWith('sqlite_'))
        .toSet();

    expect(
      indexNames,
      containsAll(<String>{
        'idx_transactions_budget_occurred',
        'idx_transactions_budget_category_occurred',
        'idx_transactions_budget_account_occurred',
        'uq_plans_budget_month_category',
        'idx_sync_operations_budget_clock',
      }),
    );
  });

  test('plan uniqueness is enforced by schema', () async {
    await database.customStatement(
      "INSERT INTO users (id, name, public_key) VALUES ('u1', 'User', 'key')",
    );
    await database.customStatement(
      "INSERT INTO budgets (id, name, base_currency, created_by) "
      "VALUES ('b1', 'Budget', 'EUR', 'u1')",
    );
    await database.customStatement(
      "INSERT INTO categories (id, budget_id, name, kind) "
      "VALUES ('c1', 'b1', 'Food', 'EXPENSE')",
    );
    await database.customStatement(
      "INSERT INTO plans "
      "(id, budget_id, month, category_id, planned_amount_minor) "
      "VALUES ('p1', 'b1', ?, 'c1', 1000)",
      [DateTime(2026, 9).millisecondsSinceEpoch ~/ 1000],
    );

    expect(
      () => database.customStatement(
        "INSERT INTO plans "
        "(id, budget_id, month, category_id, planned_amount_minor) "
        "VALUES ('p2', 'b1', ?, 'c1', 2000)",
        [DateTime(2026, 9).millisecondsSinceEpoch ~/ 1000],
      ),
      throwsA(anything),
    );
  });
}

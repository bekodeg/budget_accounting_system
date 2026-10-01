import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:drift/drift.dart';
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

  Future<String> queryPlan(
    String sql,
    List<Variable<Object>> variables,
  ) async {
    final rows = await database
        .customSelect('EXPLAIN QUERY PLAN $sql', variables: variables)
        .get();
    return rows.map((row) => row.read<String>('detail')).join('\n');
  }

  test('installs indexes for destination-account and sync hot paths', () async {
    final transactionIndexes = await database
        .customSelect("PRAGMA index_list('transactions')")
        .get();
    final syncIndexes = await database
        .customSelect("PRAGMA index_list('sync_operations')")
        .get();

    expect(
      transactionIndexes.map((row) => row.read<String>('name')),
      contains('idx_transactions_budget_destination_account_occurred'),
    );
    expect(
      syncIndexes.map((row) => row.read<String>('name')),
      containsAll([
        'idx_sync_operations_budget_device_clock',
        'idx_sync_operations_budget_entity_clock',
      ]),
    );
  });

  test('destination-account lookup avoids a transactions table scan', () async {
    final plan = await queryPlan(
      '''
SELECT id
FROM transactions
WHERE budget_id = ?
  AND destination_account_id = ?
  AND occurred_at >= ?
ORDER BY occurred_at
''',
      [
        Variable.withString('budget-1'),
        Variable.withString('account-2'),
        Variable.withDateTime(DateTime(2026, 1, 1)),
      ],
    );

    expect(
      plan,
      contains('idx_transactions_budget_destination_account_occurred'),
    );
    expect(plan, isNot(contains('SCAN transactions')));
  });

  test('per-device sync tail uses budget-device-clock index', () async {
    final plan = await queryPlan(
      '''
SELECT op_id
FROM sync_operations
WHERE budget_id = ?
  AND device_id = ?
  AND logical_clock > 100
ORDER BY logical_clock, op_id
LIMIT 100
''',
      [
        Variable.withString('budget-1'),
        Variable.withString('device-1'),
      ],
    );

    expect(plan, contains('idx_sync_operations_budget_device_clock'));
    expect(plan, isNot(contains('SCAN sync_operations')));
  });

  test('entity materialization uses entity-clock index', () async {
    final plan = await queryPlan(
      '''
SELECT op_id
FROM sync_operations
WHERE budget_id = ?
  AND entity_type = ?
  AND entity_id = ?
ORDER BY logical_clock, device_id, op_id
''',
      [
        Variable.withString('budget-1'),
        Variable.withString('transaction'),
        Variable.withString('transaction-1'),
      ],
    );

    expect(plan, contains('idx_sync_operations_budget_entity_clock'));
    expect(plan, isNot(contains('SCAN sync_operations')));
  });
}

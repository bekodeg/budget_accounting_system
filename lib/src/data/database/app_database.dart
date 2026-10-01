import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Budgets,
    BudgetMembers,
    Categories,
    Accounts,
    Devices,
    Receipts,
    BudgetTransactions,
    Plans,
    SyncOperations,
    CategoryTemplates,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'budget_accounting',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  AppDatabase.encrypted({required String key, required String databasePath})
    : super(
        driftDatabase(
          name: 'budget_accounting',
          native: DriftNativeOptions(
            shareAcrossIsolates: true,
            databasePath: () async => databasePath,
            setup: (database) {
              database.execute("PRAGMA key = '$key';");
            },
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) async {
      await migrator.createAll();
      await _seedCategoryTemplates();
    },
    onUpgrade: (Migrator migrator, int from, int to) async {
      throw StateError(
        'Missing Drift migration from schema $from to $to. '
        'Run `dart run drift_dev make-migrations` after bumping schemaVersion.',
      );
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await _ensurePerformanceIndexes();
    },
  );

  Future<void> _ensurePerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS '
      'idx_transactions_budget_destination_account_occurred '
      'ON transactions (budget_id, destination_account_id, occurred_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_budget_device_clock '
      'ON sync_operations (budget_id, device_id, logical_clock, op_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_operations_budget_entity_clock '
      'ON sync_operations '
      '(budget_id, entity_type, entity_id, logical_clock, device_id, op_id)',
    );
  }

  Future<void> _seedCategoryTemplates() async {
    await batch((Batch batch) {
      batch.insertAll(
        categoryTemplates,
        _defaultCategoryTemplates,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}

final List<CategoryTemplatesCompanion> _defaultCategoryTemplates = [
  CategoryTemplatesCompanion.insert(
    code: 'expense.food',
    name: 'Продукты',
    kind: 'EXPENSE',
    sortOrder: 10,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.cafe',
    name: 'Кафе и рестораны',
    kind: 'EXPENSE',
    sortOrder: 20,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.transport',
    name: 'Транспорт',
    kind: 'EXPENSE',
    sortOrder: 30,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.housing',
    name: 'Жилье',
    kind: 'EXPENSE',
    sortOrder: 40,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.utilities',
    name: 'Коммунальные услуги',
    kind: 'EXPENSE',
    sortOrder: 50,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.health',
    name: 'Здоровье',
    kind: 'EXPENSE',
    sortOrder: 60,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.clothing',
    name: 'Одежда',
    kind: 'EXPENSE',
    sortOrder: 70,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.entertainment',
    name: 'Развлечения',
    kind: 'EXPENSE',
    sortOrder: 80,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.education',
    name: 'Образование',
    kind: 'EXPENSE',
    sortOrder: 90,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.subscriptions',
    name: 'Подписки',
    kind: 'EXPENSE',
    sortOrder: 100,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.gifts',
    name: 'Подарки',
    kind: 'EXPENSE',
    sortOrder: 110,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'expense.other',
    name: 'Другое',
    kind: 'EXPENSE',
    sortOrder: 999,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'income.salary',
    name: 'Зарплата',
    kind: 'INCOME',
    sortOrder: 10,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'income.side_job',
    name: 'Подработка',
    kind: 'INCOME',
    sortOrder: 20,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'income.investments',
    name: 'Инвестиционный доход',
    kind: 'INCOME',
    sortOrder: 30,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'income.refund',
    name: 'Возвраты',
    kind: 'INCOME',
    sortOrder: 40,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'income.gifts',
    name: 'Подарки',
    kind: 'INCOME',
    sortOrder: 50,
  ),
  CategoryTemplatesCompanion.insert(
    code: 'income.other',
    name: 'Другое',
    kind: 'INCOME',
    sortOrder: 999,
  ),
];

import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get publicKey => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseCurrency => text().withLength(min: 3, max: 3)();
  TextColumn get createdBy => text().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BudgetMembers extends Table {
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get revokedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {budgetId, userId};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  Int64Column get openingBalanceMinor =>
      int64().withDefault(const Constant(BigInt.zero))();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get userId =>
      text().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get revokedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Receipts extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get rawQr => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get merchant => text().nullable()();
  DateTimeColumn get receiptTime => dateTime().nullable()();
  Int64Column get totalMinor => int64().nullable()();
  TextColumn get parsedPayload => text().nullable()();
  TextColumn get parseStatus => text().withDefault(const Constant('NEW'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_transactions_budget_occurred',
  columns: {#budgetId, #occurredAt},
)
@TableIndex(
  name: 'idx_transactions_budget_category_occurred',
  columns: {#budgetId, #categoryId, #occurredAt},
)
@TableIndex(
  name: 'idx_transactions_budget_account_occurred',
  columns: {#budgetId, #accountId, #occurredAt},
)
@DataClassName('BudgetTransaction')
class BudgetTransactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get occurredAt => dateTime()();
  Int64Column get amountMinor => int64()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get type => text()();
  TextColumn get authorId => text().references(Users, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get destinationAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get receiptId => text().nullable().unique().references(Receipts, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'uq_plans_budget_month_category',
  columns: {#budgetId, #month, #categoryId},
  unique: true,
)
class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get month => dateTime()();
  TextColumn get categoryId => text().references(Categories, #id)();
  Int64Column get plannedAmountMinor => int64()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_sync_operations_budget_clock',
  columns: {#budgetId, #logicalClock},
)
class SyncOperations extends Table {
  TextColumn get opId => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get opType => text()();
  TextColumn get patch => text()();
  TextColumn get authorId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  Int64Column get logicalClock => int64()();
  BlobColumn get signature => blob()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {opId};
}

class CategoryTemplates extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

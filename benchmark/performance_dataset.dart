import 'package:drift/drift.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';

Future<void> seedPerformanceReferenceData(AppDatabase database) async {
  await database
      .into(database.users)
      .insert(
        UsersCompanion.insert(
          id: 'user-1',
          name: 'Performance User',
          publicKey: 'ed25519:performance',
        ),
      );
  await database
      .into(database.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: 'budget-1',
          name: 'Performance Budget',
          baseCurrency: 'EUR',
          createdBy: 'user-1',
        ),
      );
  await database
      .into(database.budgetMembers)
      .insert(
        BudgetMembersCompanion.insert(
          budgetId: 'budget-1',
          userId: 'user-1',
          role: 'OWNER',
        ),
      );

  await database.batch((batch) {
    batch.insertAll(database.devices, [
      for (var index = 1; index <= 5; index += 1)
        DevicesCompanion.insert(
          id: 'device-$index',
          userId: 'user-1',
          name: Value('Device $index'),
        ),
    ]);
    batch.insertAll(database.accounts, [
      for (var index = 1; index <= 4; index += 1)
        AccountsCompanion.insert(
          id: 'account-$index',
          budgetId: 'budget-1',
          name: 'Account $index',
          openingBalanceMinor: Value(BigInt.from(index * 100000)),
          currency: 'EUR',
        ),
    ]);
    batch.insertAll(database.categories, [
      for (var index = 1; index <= 12; index += 1)
        CategoriesCompanion.insert(
          id: 'category-$index',
          budgetId: 'budget-1',
          name: 'Category $index',
          kind: index <= 2 ? 'INCOME' : 'EXPENSE',
        ),
    ]);
  });
}

Future<void> seedPerformanceTransactions(
  AppDatabase database,
  int count,
) async {
  const chunkSize = 1000;
  final start = DateTime.utc(2021, 1, 1);

  for (var offset = 0; offset < count; offset += chunkSize) {
    final end = (offset + chunkSize < count) ? offset + chunkSize : count;
    final rows = <BudgetTransactionsCompanion>[];

    for (var index = offset; index < end; index += 1) {
      final source = (index % 4) + 1;
      final isTransfer = index % 10 == 0;
      final isIncome = !isTransfer && index % 4 == 0;
      final occurredAt = start.add(Duration(hours: index));

      rows.add(
        BudgetTransactionsCompanion.insert(
          id: 'transaction-$index',
          budgetId: 'budget-1',
          occurredAt: occurredAt,
          amountMinor: BigInt.from(100 + (index % 100000)),
          currency: 'EUR',
          type: isTransfer ? 'TRANSFER' : (isIncome ? 'INCOME' : 'EXPENSE'),
          authorId: 'user-1',
          accountId: 'account-$source',
          destinationAccountId: Value(
            isTransfer ? 'account-${(source % 4) + 1}' : null,
          ),
          categoryId: Value(isTransfer ? null : 'category-${(index % 12) + 1}'),
          createdAt: Value(occurredAt),
          updatedAt: Value(occurredAt),
        ),
      );
    }

    await database.batch((batch) {
      batch.insertAll(database.budgetTransactions, rows);
    });
  }
}

Future<void> seedPerformanceSyncOperations(
  AppDatabase database,
  int count,
) async {
  const chunkSize = 1000;
  final signature = Uint8List.fromList(const [1, 2, 3, 4]);
  final start = DateTime.utc(2021, 1, 1);

  for (var offset = 0; offset < count; offset += chunkSize) {
    final end = (offset + chunkSize < count) ? offset + chunkSize : count;
    final rows = <SyncOperationsCompanion>[];

    for (var index = offset; index < end; index += 1) {
      final deviceNumber = (index % 5) + 1;
      rows.add(
        SyncOperationsCompanion.insert(
          opId: 'operation-$index',
          budgetId: 'budget-1',
          entityType: 'transaction',
          entityId: 'transaction-${index % 10000}',
          opType: 'PATCH',
          patch: '{"amount_minor":${100 + (index % 100000)}}',
          authorId: 'user-1',
          deviceId: 'device-$deviceNumber',
          logicalClock: BigInt.from((index ~/ 5) + 1),
          signature: signature,
          createdAt: Value(start.add(Duration(minutes: index))),
        ),
      );
    }

    await database.batch((batch) {
      batch.insertAll(database.syncOperations, rows);
    });
  }
}

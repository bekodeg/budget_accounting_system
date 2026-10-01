// ignore_for_file: avoid_print

import 'dart:io';

import 'package:budget_accounting_system/src/data/dal/report_dao.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_dashboard_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_extended_report_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_monthly_report_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'large local history stays inside the S6 performance budgets',
    () async {
    final transactionCount = _envInt('PERF_TRANSACTION_COUNT', 50000);
    final syncOperationCount = _envInt('PERF_SYNC_OPERATION_COUNT', 50000);
    final database = AppDatabase(NativeDatabase.memory());

    try {
      final setup = Stopwatch()..start();
      await _seedReferenceData(database);
      await _seedTransactions(database, transactionCount);
      await _seedSyncOperations(database, syncOperationCount);
      setup.stop();

      final pageCount = await database
          .customSelect('PRAGMA page_count')
          .getSingle();
      final pageSize = await database
          .customSelect('PRAGMA page_size')
          .getSingle();
      final databaseBytes =
          pageCount.read<int>('page_count') * pageSize.read<int>('page_size');

      print('PERF dataset_transactions=$transactionCount');
      print('PERF dataset_sync_operations=$syncOperationCount');
      print('PERF setup_ms=${setup.elapsedMilliseconds}');
      print('PERF database_bytes=$databaseBytes');

      final transactionDao = TransactionDao(database);
      final reportDao = ReportDao(database);
      final syncDao = SyncDao(database);

      final activeList = await _measure(() async {
        final rows = await transactionDao.watchActive('budget-1').first;
        expect(rows.length, transactionCount);
      });

      final dashboard = await _measure(() async {
        final value = await DriftDashboardRepository(reportDao)
            .watchSummary(
              budgetId: 'budget-1',
              monthStart: DateTime(2026, 9),
            )
            .first;
        expect(value.balanceMinorByCurrency, isNotEmpty);
      });

      final monthlyReport = await _measure(() async {
        final value = await DriftMonthlyReportRepository(reportDao)
            .watchMonthlyReport(
              budgetId: 'budget-1',
              monthStart: DateTime(2026, 9),
            )
            .first;
        expect(value.accountBalances, hasLength(4));
      });

      final yearReport = await _measure(() async {
        final value = await DriftExtendedReportRepository(reportDao)
            .watchYearReport(budgetId: 'budget-1', year: 2026)
            .first;
        expect(value.months, hasLength(12));
      });

      final stateVector = await _measure(() async {
        final value = await syncDao.getStateVector('budget-1');
        expect(value, hasLength(5));
      });

      final syncTail = await _measure(() async {
        final value = await syncDao.getDeviceOperationsAfter(
          budgetId: 'budget-1',
          deviceId: 'device-1',
          logicalClock: BigInt.zero,
          limit: 500,
        );
        expect(value, hasLength(500));
      });

      _reportAndAssert(
        'active_list',
        activeList,
        _envInt('PERF_ACTIVE_LIST_MAX_MS', 8000),
      );
      _reportAndAssert(
        'dashboard',
        dashboard,
        _envInt('PERF_DASHBOARD_MAX_MS', 4000),
      );
      _reportAndAssert(
        'monthly_report',
        monthlyReport,
        _envInt('PERF_MONTHLY_REPORT_MAX_MS', 5000),
      );
      _reportAndAssert(
        'year_report',
        yearReport,
        _envInt('PERF_YEAR_REPORT_MAX_MS', 6000),
      );
      _reportAndAssert(
        'sync_state_vector',
        stateVector,
        _envInt('PERF_SYNC_STATE_MAX_MS', 2500),
      );
      _reportAndAssert(
        'sync_tail_500',
        syncTail,
        _envInt('PERF_SYNC_TAIL_MAX_MS', 1500),
      );
    } finally {
      await database.close();
    }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

int _envInt(String name, int fallback) {
  return int.tryParse(Platform.environment[name] ?? '') ?? fallback;
}

Future<Duration> _measure(Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  return stopwatch.elapsed;
}

void _reportAndAssert(String name, Duration elapsed, int maxMilliseconds) {
  final actual = elapsed.inMilliseconds;
  print('PERF ${name}_ms=$actual budget_ms=$maxMilliseconds');
  expect(
    actual,
    lessThanOrEqualTo(maxMilliseconds),
    reason: '$name exceeded the S6 performance budget',
  );
}

Future<void> _seedReferenceData(AppDatabase database) async {
  await database.into(database.users).insert(
    UsersCompanion.insert(
      id: 'user-1',
      name: 'Performance User',
      publicKey: 'ed25519:performance',
    ),
  );
  await database.into(database.budgets).insert(
    BudgetsCompanion.insert(
      id: 'budget-1',
      name: 'Performance Budget',
      baseCurrency: 'EUR',
      createdBy: 'user-1',
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

Future<void> _seedTransactions(AppDatabase database, int count) async {
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
          categoryId: Value(
            isTransfer ? null : 'category-${(index % 12) + 1}',
          ),
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

Future<void> _seedSyncOperations(AppDatabase database, int count) async {
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

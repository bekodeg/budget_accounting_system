// ignore_for_file: avoid_print

import 'dart:io';

import 'package:budget_accounting_system/src/data/dal/report_dao.dart';
import 'package:budget_accounting_system/src/data/dal/sync_dao.dart';
import 'package:budget_accounting_system/src/data/dal/transaction_dao.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_dashboard_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_extended_report_repository.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_monthly_report_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'performance_dataset.dart';

void main() {
  test('large local history stays inside the S6 performance budgets', () async {
    final transactionCount = _envInt('PERF_TRANSACTION_COUNT', 50000);
    final syncOperationCount = _envInt('PERF_SYNC_OPERATION_COUNT', 50000);
    final database = AppDatabase(NativeDatabase.memory());

    try {
      final setup = Stopwatch()..start();
      await seedPerformanceReferenceData(database);
      await seedPerformanceTransactions(database, transactionCount);
      await seedPerformanceSyncOperations(database, syncOperationCount);
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
            .watchSummary(budgetId: 'budget-1', monthStart: DateTime(2026, 9))
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
        final value = await DriftExtendedReportRepository(
          reportDao,
        ).watchYearReport(budgetId: 'budget-1', year: 2026).first;
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
  }, timeout: const Timeout(Duration(minutes: 10)));
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

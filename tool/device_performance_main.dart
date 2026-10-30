// A separate Android application ID must be used with this entrypoint.
// It seeds only synthetic data and must never run against the production app.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:budget_accounting_system/src/bootstrap/app_composition_root.dart';
import 'package:budget_accounting_system/src/bootstrap/database_encryption_bootstrap.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/preferences/shared_preferences_session_store.dart';
import 'package:budget_accounting_system/src/data/security/flutter_secure_database_key_store.dart';
import 'package:budget_accounting_system/src/data/services/random_secure_token_generator.dart';
import 'package:budget_accounting_system/src/presentation/screens/app_shell.dart';

import '../benchmark/performance_dataset.dart';

const _transactionCount = int.fromEnvironment(
  'PERF_TRANSACTION_COUNT',
  defaultValue: 50000,
);
const _syncOperationCount = int.fromEnvironment(
  'PERF_SYNC_OPERATION_COUNT',
  defaultValue: 50000,
);
const _identityChannel = MethodChannel('budget_performance/identity');
const performancePackageId = 'com.bekodeg.perftest.budget_accounting_system';

void verifyPerformancePackage(String? packageId) {
  if (packageId != performancePackageId) {
    throw StateError('Performance dataset requires $performancePackageId.');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DevicePerformanceApp());
}

final class _DevicePerformanceApp extends StatefulWidget {
  const _DevicePerformanceApp();

  @override
  State<_DevicePerformanceApp> createState() => _DevicePerformanceAppState();
}

final class _DevicePerformanceAppState extends State<_DevicePerformanceApp> {
  late final Stopwatch _startup;
  late final Future<AppCompositionRoot> _runtime;
  AppCompositionRoot? _root;
  bool _firstFrameLogged = false;
  final List<FrameTiming> _frameTimings = [];

  @override
  void initState() {
    super.initState();
    _startup = Stopwatch()..start();
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _runtime = _load();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameTimings.add(timing);
      if (_frameTimings.length < 30) continue;
      final sorted =
          _frameTimings.map((frame) => frame.totalSpan.inMicroseconds).toList()
            ..sort();
      final over16ms = sorted.where((duration) => duration > 16000).length;
      final slowest = _frameTimings.reduce(
        (current, next) => next.totalSpan > current.totalSpan ? next : current,
      );
      debugPrint(
        'PERF_DEVICE frames=30 p50_ms=${sorted[15] / 1000} '
        'p90_ms=${sorted[27] / 1000} max_ms=${sorted.last / 1000} '
        'max_build_ms=${slowest.buildDuration.inMicroseconds / 1000} '
        'max_raster_ms=${slowest.rasterDuration.inMicroseconds / 1000} '
        'over16ms=$over16ms elapsed_ms=${_startup.elapsedMilliseconds}',
      );
      _frameTimings.clear();
    }
  }

  Future<AppCompositionRoot> _load() async {
    verifyPerformancePackage(
      await _identityChannel.invokeMethod<String>('packageName'),
    );
    final config = await DatabaseEncryptionBootstrap(
      keyStore: FlutterSecureDatabaseKeyStore(),
      tokenGenerator: RandomSecureTokenGenerator(),
    ).prepare();
    final database = AppDatabase.encrypted(
      key: config.key,
      databasePath: config.databasePath,
    );
    try {
      final count = await database
          .customSelect(
            "SELECT COUNT(*) AS n FROM transactions WHERE budget_id = 'budget-1'",
          )
          .getSingle();
      final existing = count.read<int>('n');
      if (existing == 0) {
        final seed = Stopwatch()..start();
        await database.transaction(() async {
          await seedPerformanceReferenceData(database);
          await seedPerformanceTransactions(database, _transactionCount);
          await seedPerformanceSyncOperations(database, _syncOperationCount);
        });
        seed.stop();
        debugPrint('PERF_DEVICE seed_ms=${seed.elapsedMilliseconds}');
      } else if (existing != _transactionCount) {
        throw StateError(
          'Existing dataset has $existing transactions; expected $_transactionCount. '
          'Clear only the isolated performance app data before changing size.',
        );
      }
      await SharedPreferencesSessionStore().saveSession(
        userId: 'user-1',
        budgetId: 'budget-1',
      );
      final root = AppCompositionRoot.defaults(database: database);
      _root = root;
      debugPrint(
        'PERF_DEVICE ready_ms=${_startup.elapsedMilliseconds} '
        'transactions=$_transactionCount sync_operations=$_syncOperationCount',
      );
      return root;
    } on Object {
      await database.close();
      rethrow;
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _root?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Budget Performance Test',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: FutureBuilder<AppCompositionRoot>(
      future: _runtime,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('${snapshot.error}')));
        }
        final root = snapshot.data;
        if (root == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_firstFrameLogged) {
          _firstFrameLogged = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              'PERF_DEVICE app_shell_first_frame_ms=${_startup.elapsedMilliseconds}',
            );
          });
        }
        return AppShell(
          services: root.services,
          userId: 'user-1',
          budgetId: 'budget-1',
          budgetName: 'Performance Budget',
        );
      },
    ),
  );
}

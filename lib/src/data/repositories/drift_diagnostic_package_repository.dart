import 'dart:convert';
import 'dart:io';

import '../../application/ports/diagnostic_log_store.dart';
import '../../application/ports/diagnostic_package_repository.dart';
import '../../application/services/budget_snapshot_codec.dart';
import '../../domain/models/diagnostic_package.dart';
import '../database/app_database.dart';

final class DriftDiagnosticPackageRepository
    implements DiagnosticPackageRepository {
  const DriftDiagnosticPackageRepository({
    required AppDatabase database,
    required DiagnosticLogStore logStore,
  }) : _database = database,
       _logStore = logStore;

  final AppDatabase _database;
  final DiagnosticLogStore _logStore;

  @override
  Future<DiagnosticPackageBundle> collect() async {
    final logs = await _logStore.readRecent(limit: 100);
    final budgetCount = await _count('budgets');
    final syncOperationCount = await _count('sync_operations');
    final failedReceiptCount = await _count(
      'receipts',
      where: "parse_status = 'FAILED'",
    );

    const appVersion = String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '0.1.0+2',
    );
    final platform = Platform.operatingSystem;
    final generatedAt = DateTime.now().toUtc();

    final diagnostics = <String, Object?>{
      'format': 'budget-accounting-diagnostics',
      'v': 1,
      'generated_at': generatedAt.toIso8601String(),
      'app': {
        'version': appVersion,
        'schema_version': _database.schemaVersion,
        'snapshot_protocol_version': BudgetSnapshotCodec.currentVersion,
      },
      'platform': {
        'os': platform,
        'os_version': _safeOsVersion(Platform.operatingSystemVersion),
      },
      'technical_counts': {
        'budgets': budgetCount,
        'sync_operations': syncOperationCount,
        'failed_receipts': failedReceiptCount,
        'recent_errors': logs.length,
      },
      'privacy': {
        'contains_financial_amounts': false,
        'contains_transaction_descriptions': false,
        'contains_qr_payloads': false,
        'contains_private_keys': false,
        'contains_user_names_or_ids': false,
      },
    };

    final errors = logs
        .map((record) => jsonEncode(record.toJson()))
        .join('\n');

    final preview = DiagnosticPackagePreview(
      appVersion: appVersion,
      schemaVersion: _database.schemaVersion,
      snapshotProtocolVersion: BudgetSnapshotCodec.currentVersion,
      platform: platform,
      budgetCount: budgetCount,
      syncOperationCount: syncOperationCount,
      failedReceiptCount: failedReceiptCount,
      recentErrorCount: logs.length,
      archiveEntries: const ['diagnostics.json', 'errors.jsonl'],
    );

    return DiagnosticPackageBundle(
      preview: preview,
      diagnosticsJson: const JsonEncoder.withIndent('  ').convert(diagnostics),
      errorsJsonLines: errors.isEmpty ? '' : '$errors\n',
    );
  }

  Future<int> _count(String table, {String? where}) async {
    final sql =
        'SELECT COUNT(*) AS count_value FROM $table'
        '${where == null ? '' : ' WHERE $where'}';
    final row = await _database.customSelect(sql).getSingle();
    return row.read<int>('count_value');
  }

  String _safeOsVersion(String raw) {
    final firstLine = raw.split('\n').first.trim();
    final sanitized = firstLine.replaceAll(
      RegExp(r'[^A-Za-z0-9 ._()\/-]'),
      '',
    );
    return sanitized.length <= 120
        ? sanitized
        : sanitized.substring(0, 120);
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:drift/native.dart';

final class DriftSnapshotHarness {
  const DriftSnapshotHarness(this.snapshotPath);

  final String snapshotPath;

  AppDatabase openCurrent({
    List<String> setupSql = const [],
  }) {
    final snapshot = _readSnapshot();
    final version = snapshot.version;
    final statements = snapshot.createStatements;

    final executor = NativeDatabase.memory(
      setup: (database) {
        for (final statement in statements) {
          database.execute(statement);
        }
        for (final statement in setupSql) {
          database.execute(statement);
        }
        database.execute('PRAGMA user_version = $version');
      },
    );

    return AppDatabase(executor);
  }

  _Snapshot _readSnapshot() {
    final payload =
        jsonDecode(File(snapshotPath).readAsStringSync()) as Map<String, Object?>;
    final fixedSql = payload['fixed_sql'] as List<Object?>;

    final createStatements = <String>[];
    for (final entry in fixedSql) {
      final map = entry! as Map<String, Object?>;
      final sqlEntries = map['sql'] as List<Object?>;
      for (final sqlEntry in sqlEntries) {
        final sqlMap = sqlEntry! as Map<String, Object?>;
        if (sqlMap['dialect'] == 'sqlite') {
          createStatements.add(sqlMap['sql']! as String);
        }
      }
    }

    final fileName = snapshotPath.split(Platform.pathSeparator).last;
    final match = RegExp(r'drift_schema_v(\d+)\.json').firstMatch(fileName);
    if (match == null) {
      throw FormatException(
        'Unable to infer schema version from $snapshotPath',
      );
    }

    return _Snapshot(
      version: int.parse(match.group(1)!),
      createStatements: createStatements,
    );
  }
}

final class _Snapshot {
  const _Snapshot({
    required this.version,
    required this.createStatements,
  });

  final int version;
  final List<String> createStatements;
}

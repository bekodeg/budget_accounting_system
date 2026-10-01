import 'dart:io';

import 'package:budget_accounting_system/src/data/services/rotating_diagnostic_log_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe diagnostic log rotates and bounds retained files', () async {
    final directory = await Directory.systemTemp.createTemp('diagnostic-log-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final store = RotatingDiagnosticLogStore(
      directoryResolver: () async => directory,
      maxFileBytes: 80,
      maxFiles: 2,
    );

    for (var index = 0; index < 12; index += 1) {
      await store.append(
        category: 'DB unsafe words',
        code: 'Error #$index with spaces',
      );
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.jsonl'))
        .toList();
    expect(files.length, lessThanOrEqualTo(2));

    final recent = await store.readRecent(limit: 5);
    expect(recent, isNotEmpty);
    expect(recent.length, lessThanOrEqualTo(5));
    for (final record in recent) {
      expect(record.category, matches(RegExp(r'^[a-z0-9_.-]+$')));
      expect(record.code, matches(RegExp(r'^[a-z0-9_.-]+$')));
    }
  });
}

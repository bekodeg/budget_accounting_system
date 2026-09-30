import 'dart:io';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/data/services/report_temp_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates and cleans temporary CSV and XLSX files', () async {
    const store = ReportTempFileStore();
    final root = await Directory.systemTemp.createTemp('budget-export-test-');

    try {
      final files = await store.create(
        rootDirectory: root,
        baseName: 'budget_test_20260901_20261001',
        csvBytes: Uint8List.fromList([1, 2, 3]),
        xlsxBytes: Uint8List.fromList([4, 5, 6]),
      );

      expect(await files.csvFile.exists(), isTrue);
      expect(await files.xlsxFile.exists(), isTrue);
      expect(await files.csvFile.readAsBytes(), [1, 2, 3]);
      expect(await files.xlsxFile.readAsBytes(), [4, 5, 6]);

      await store.cleanup(files);

      expect(await files.directory.exists(), isFalse);
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });
}

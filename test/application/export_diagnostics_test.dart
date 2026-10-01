import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:budget_accounting_system/src/application/ports/diagnostic_package_repository.dart';
import 'package:budget_accounting_system/src/application/ports/diagnostic_share_gateway.dart';
import 'package:budget_accounting_system/src/application/use_cases/export_diagnostics.dart';
import 'package:budget_accounting_system/src/domain/models/diagnostic_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostic export creates expected two-file zip snapshot', () async {
    final share = _ShareGateway();
    final export = ExportDiagnostics(
      repository: const _Repository(),
      shareGateway: share,
    );

    await export();

    final archive = ZipDecoder().decodeBytes(share.bytes!);
    final names = archive.files.map((file) => file.name).toList()..sort();
    expect(names, ['diagnostics.json', 'errors.jsonl']);

    final diagnostics = archive.files.firstWhere(
      (file) => file.name == 'diagnostics.json',
    );
    final content = utf8.decode(diagnostics.content as List<int>);
    expect(content, '{"safe":true}');
    expect(content, isNot(contains('secret')));
  });
}

final class _Repository implements DiagnosticPackageRepository {
  const _Repository();

  @override
  Future<DiagnosticPackageBundle> collect() async {
    return const DiagnosticPackageBundle(
      preview: DiagnosticPackagePreview(
        appVersion: '1',
        schemaVersion: 5,
        snapshotProtocolVersion: 1,
        platform: 'test',
        budgetCount: 1,
        syncOperationCount: 2,
        failedReceiptCount: 0,
        recentErrorCount: 1,
        archiveEntries: ['diagnostics.json', 'errors.jsonl'],
      ),
      diagnosticsJson: '{"safe":true}',
      errorsJsonLines:
          '{"timestamp":"2026-10-01T00:00:00Z","category":"db","code":"SqliteException"}\n',
    );
  }
}

final class _ShareGateway implements DiagnosticShareGateway {
  Uint8List? bytes;

  @override
  Future<void> share({
    required String fileName,
    required Uint8List zipBytes,
  }) async {
    expect(fileName, endsWith('.zip'));
    bytes = zipBytes;
  }
}

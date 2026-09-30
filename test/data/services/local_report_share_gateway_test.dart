import 'dart:io';
import 'dart:typed_data';

import 'package:budget_accounting_system/src/data/services/local_report_share_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes two files, clears stale exports and shares current paths', () async {
    final directory = await Directory.systemTemp.createTemp(
      'budget-export-test-',
    );
    addTearDown(() => directory.delete(recursive: true));

    await File(
      '${directory.path}${Platform.pathSeparator}stale.csv',
    ).writeAsString('stale');

    List<String>? sharedPaths;
    List<String>? sharedNames;
    final gateway = LocalReportShareGateway(
      directoryProvider: () async => directory,
      shareFiles: (paths, names) async {
        sharedPaths = List.of(paths);
        sharedNames = List.of(names);
      },
    );

    final result = await gateway.share(
      baseName: 'budget_home_20260901_20261001',
      csvBytes: Uint8List.fromList([1, 2, 3]),
      xlsxBytes: Uint8List.fromList([4, 5, 6]),
    );

    final entities = await directory.list().toList();
    expect(entities, hasLength(2));
    expect(
      entities.map((entity) => entity.path),
      isNot(contains(endsWith('stale.csv'))),
    );
    expect(
      result.csvFileName,
      'budget_home_20260901_20261001.csv',
    );
    expect(
      result.xlsxFileName,
      'budget_home_20260901_20261001.xlsx',
    );
    expect(
      sharedNames,
      [
        'budget_home_20260901_20261001.csv',
        'budget_home_20260901_20261001.xlsx',
      ],
    );
    expect(sharedPaths, hasLength(2));

    expect(
      await File(sharedPaths![0]).readAsBytes(),
      [1, 2, 3],
    );
    expect(
      await File(sharedPaths![1]).readAsBytes(),
      [4, 5, 6],
    );
  });

  test('next export replaces previous temporary files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'budget-export-replace-test-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final gateway = LocalReportShareGateway(
      directoryProvider: () async => directory,
      shareFiles: (_, __) async {},
    );

    await gateway.share(
      baseName: 'first',
      csvBytes: Uint8List.fromList([1]),
      xlsxBytes: Uint8List.fromList([2]),
    );
    await gateway.share(
      baseName: 'second',
      csvBytes: Uint8List.fromList([3]),
      xlsxBytes: Uint8List.fromList([4]),
    );

    final names = (await directory.list().toList())
        .map((entity) => entity.uri.pathSegments.last)
        .toList()
      ..sort();

    expect(names, ['second.csv', 'second.xlsx']);
  });
}

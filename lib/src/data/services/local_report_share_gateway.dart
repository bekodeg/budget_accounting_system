import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../application/ports/report_share_gateway.dart';
import '../../domain/models/report_export.dart';

typedef ExportDirectoryProvider = Future<Directory> Function();
typedef ShareReportFiles =
    Future<void> Function(List<String> paths, List<String> fileNames);

final class LocalReportShareGateway implements ReportShareGateway {
  LocalReportShareGateway({
    ExportDirectoryProvider? directoryProvider,
    ShareReportFiles? shareFiles,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory,
       _shareFiles = shareFiles ?? _defaultShare;

  final ExportDirectoryProvider _directoryProvider;
  final ShareReportFiles _shareFiles;

  @override
  Future<ReportExportResult> share({
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  }) async {
    final directory = await _directoryProvider();
    await _resetDirectory(directory);

    final csvFileName = '$baseName.csv';
    final xlsxFileName = '$baseName.xlsx';
    final csvFile = File(
      '${directory.path}${Platform.pathSeparator}$csvFileName',
    );
    final xlsxFile = File(
      '${directory.path}${Platform.pathSeparator}$xlsxFileName',
    );

    await csvFile.writeAsBytes(csvBytes, flush: true);
    await xlsxFile.writeAsBytes(xlsxBytes, flush: true);

    await _shareFiles(
      [csvFile.path, xlsxFile.path],
      [csvFileName, xlsxFileName],
    );

    return ReportExportResult(
      csvFileName: csvFileName,
      xlsxFileName: xlsxFileName,
    );
  }

  Future<void> _resetDirectory(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      return;
    }

    await for (final entity in directory.list()) {
      await entity.delete(recursive: true);
    }
  }

  static Future<Directory> _defaultDirectory() async {
    return Directory(
      '${Directory.systemTemp.path}'
      '${Platform.pathSeparator}budget_accounting_exports',
    );
  }

  static Future<void> _defaultShare(
    List<String> paths,
    List<String> fileNames,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Экспорт бюджета',
        files: [for (final path in paths) XFile(path)],
        fileNameOverrides: fileNames,
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';

final class ReportTempFiles {
  const ReportTempFiles({
    required this.directory,
    required this.csvFile,
    required this.xlsxFile,
  });

  final Directory directory;
  final File csvFile;
  final File xlsxFile;
}

final class ReportTempFileStore {
  const ReportTempFileStore();

  Future<ReportTempFiles> create({
    required Directory rootDirectory,
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  }) async {
    final exportDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}budget_report_export',
    );

    if (await exportDirectory.exists()) {
      await exportDirectory.delete(recursive: true);
    }
    await exportDirectory.create(recursive: true);

    final csvFile = File(
      '${exportDirectory.path}${Platform.pathSeparator}$baseName.csv',
    );
    final xlsxFile = File(
      '${exportDirectory.path}${Platform.pathSeparator}$baseName.xlsx',
    );

    await csvFile.writeAsBytes(csvBytes, flush: true);
    await xlsxFile.writeAsBytes(xlsxBytes, flush: true);

    return ReportTempFiles(
      directory: exportDirectory,
      csvFile: csvFile,
      xlsxFile: xlsxFile,
    );
  }

  Future<void> cleanup(ReportTempFiles files) async {
    if (await files.directory.exists()) {
      await files.directory.delete(recursive: true);
    }
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/ports/report_share_gateway.dart';
import '../../domain/models/report_export.dart';
import 'report_temp_file_store.dart';

final class PlatformReportShareGateway implements ReportShareGateway {
  const PlatformReportShareGateway({this.fileStore = const ReportTempFileStore()});

  final ReportTempFileStore fileStore;

  @override
  Future<ReportExportResult> share({
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  }) async {
    final tempDirectory = await getTemporaryDirectory();
    final files = await fileStore.create(
      rootDirectory: tempDirectory,
      baseName: baseName,
      csvBytes: csvBytes,
      xlsxBytes: xlsxBytes,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(files.csvFile.path, mimeType: 'text/csv'),
            XFile(
              files.xlsxFile.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          subject: 'Budget report',
        ),
      );
    } finally {
      await fileStore.cleanup(files);
    }

    return ReportExportResult(
      csvFileName: '$baseName.csv',
      xlsxFileName: '$baseName.xlsx',
    );
  }
}

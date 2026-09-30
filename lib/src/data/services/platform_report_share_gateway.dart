import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/ports/report_share_gateway.dart';
import '../../domain/models/report_export.dart';

final class PlatformReportShareGateway implements ReportShareGateway {
  const PlatformReportShareGateway();

  @override
  Future<ReportExportResult> share({
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  }) async {
    final tempDirectory = await getTemporaryDirectory();
    final exportDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}budget_report_export',
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

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(csvFile.path, mimeType: 'text/csv'),
            XFile(
              xlsxFile.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          subject: 'Budget report',
        ),
      );
    } finally {
      if (await exportDirectory.exists()) {
        await exportDirectory.delete(recursive: true);
      }
    }

    return ReportExportResult(
      csvFileName: '$baseName.csv',
      xlsxFileName: '$baseName.xlsx',
    );
  }
}

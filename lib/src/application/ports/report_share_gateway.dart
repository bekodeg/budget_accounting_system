import 'dart:typed_data';

import '../../domain/models/report_export.dart';

abstract interface class ReportShareGateway {
  Future<ReportExportResult> share({
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  });
}

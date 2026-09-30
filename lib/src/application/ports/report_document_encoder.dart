import 'dart:typed_data';

import '../../domain/models/report_export.dart';

abstract interface class ReportDocumentEncoder {
  Uint8List encodeCsv(ReportExportBundle bundle);

  Uint8List encodeXlsx(ReportExportBundle bundle);
}

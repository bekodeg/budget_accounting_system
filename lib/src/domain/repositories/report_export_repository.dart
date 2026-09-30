import '../models/report_export.dart';
import '../models/report_filter.dart';

abstract interface class ReportExportRepository {
  Future<List<ReportExportTransaction>> listTransactions(ReportFilter filter);
}

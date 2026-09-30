import '../../domain/models/period_report.dart';
import '../../domain/models/report_export.dart';
import '../../domain/models/report_filter.dart';
import '../../domain/repositories/extended_report_repository.dart';
import '../../domain/repositories/report_export_repository.dart';
import '../ports/report_document_encoder.dart';
import '../ports/report_share_gateway.dart';

final class ExportReport {
  const ExportReport({
    required ExtendedReportRepository reportRepository,
    required ReportExportRepository exportRepository,
    required ReportDocumentEncoder encoder,
    required ReportShareGateway shareGateway,
  }) : _reportRepository = reportRepository,
       _exportRepository = exportRepository,
       _encoder = encoder,
       _shareGateway = shareGateway;

  final ExtendedReportRepository _reportRepository;
  final ReportExportRepository _exportRepository;
  final ReportDocumentEncoder _encoder;
  final ReportShareGateway _shareGateway;

  Future<ReportExportResult> call(ReportFilter filter) async {
    final summaryFuture = _reportRepository.watchPeriodReport(filter).first;
    final transactionsFuture = _exportRepository.listTransactions(filter);
    final PeriodReport summary = await summaryFuture;
    final List<ReportExportTransaction> transactions =
        await transactionsFuture;

    final bundle = ReportExportBundle(
      filter: filter,
      summary: summary,
      transactions: transactions,
    );
    final baseName = buildReportExportBaseName(filter);
    return _shareGateway.share(
      baseName: baseName,
      csvBytes: _encoder.encodeCsv(bundle),
      xlsxBytes: _encoder.encodeXlsx(bundle),
    );
  }
}

String buildReportExportBaseName(ReportFilter filter) {
  final budget = _safeFileSegment(filter.budgetId);
  return 'budget_${budget}_${_compactDate(filter.fromInclusive)}_'
      '${_compactDate(filter.toExclusive)}';
}

String _safeFileSegment(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'budget' : sanitized;
}

String _compactDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}$month$day';
}

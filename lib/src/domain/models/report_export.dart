import 'domain_types.dart';
import 'period_report.dart';
import 'report_filter.dart';

final class ReportExportTransaction {
  const ReportExportTransaction({
    required this.id,
    required this.occurredAt,
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.authorId,
    required this.accountId,
    required this.destinationAccountId,
    required this.categoryId,
    required this.description,
  });

  final String id;
  final DateTime occurredAt;
  final BigInt amountMinor;
  final String currency;
  final TransactionType type;
  final String authorId;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final String? description;
}

final class ReportExportBundle {
  ReportExportBundle({
    required this.filter,
    required this.summary,
    required List<ReportExportTransaction> transactions,
  }) : transactions = List.unmodifiable(transactions);

  final ReportFilter filter;
  final PeriodReport summary;
  final List<ReportExportTransaction> transactions;
}

final class ReportExportResult {
  const ReportExportResult({
    required this.csvFileName,
    required this.xlsxFileName,
  });

  final String csvFileName;
  final String xlsxFileName;
}

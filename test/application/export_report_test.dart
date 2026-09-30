import 'dart:typed_data';

import 'package:budget_accounting_system/src/application/ports/report_document_encoder.dart';
import 'package:budget_accounting_system/src/application/ports/report_share_gateway.dart';
import 'package:budget_accounting_system/src/application/use_cases/export_report.dart';
import 'package:budget_accounting_system/src/domain/models/period_report.dart';
import 'package:budget_accounting_system/src/domain/models/report_export.dart';
import 'package:budget_accounting_system/src/domain/models/report_filter.dart';
import 'package:budget_accounting_system/src/domain/models/year_report.dart';
import 'package:budget_accounting_system/src/domain/repositories/extended_report_repository.dart';
import 'package:budget_accounting_system/src/domain/repositories/report_export_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds safe deterministic names and sends both documents to share gateway',
    () async {
      final reportRepository = _ReportRepository();
      final exportRepository = _ExportRepository();
      final encoder = _Encoder();
      final shareGateway = _ShareGateway();
      final useCase = ExportReport(
        reportRepository: reportRepository,
        exportRepository: exportRepository,
        encoder: encoder,
        shareGateway: shareGateway,
      );
      final filter = ReportFilter(
        budgetId: 'Дом / 2026',
        fromInclusive: DateTime(2026, 9, 1),
        toExclusive: DateTime(2026, 10, 1),
      );

      final result = await useCase(filter);

      expect(shareGateway.baseName, 'budget_2026_20260901_20261001');
      expect(shareGateway.csvBytes, [1, 2, 3]);
      expect(shareGateway.xlsxBytes, [4, 5, 6]);
      expect(result.csvFileName, 'budget_2026_20260901_20261001.csv');
      expect(result.xlsxFileName, 'budget_2026_20260901_20261001.xlsx');
    },
  );
}

final class _ReportRepository implements ExtendedReportRepository {
  @override
  Stream<PeriodReport> watchPeriodReport(ReportFilter filter) {
    return Stream.value(
      PeriodReport(
        fromInclusive: filter.fromInclusive,
        toExclusive: filter.toExclusive,
        incomeMinorByCurrency: const {},
        expenseMinorByCurrency: const {},
        categories: const [],
      ),
    );
  }

  @override
  Stream<YearReport> watchYearReport({
    required String budgetId,
    required int year,
  }) {
    throw UnimplementedError();
  }
}

final class _ExportRepository implements ReportExportRepository {
  @override
  Future<List<ReportExportTransaction>> listTransactions(
    ReportFilter filter,
  ) async {
    return const [];
  }
}

final class _Encoder implements ReportDocumentEncoder {
  @override
  Uint8List encodeCsv(ReportExportBundle bundle) =>
      Uint8List.fromList([1, 2, 3]);

  @override
  Uint8List encodeXlsx(ReportExportBundle bundle) =>
      Uint8List.fromList([4, 5, 6]);
}

final class _ShareGateway implements ReportShareGateway {
  String? baseName;
  List<int>? csvBytes;
  List<int>? xlsxBytes;

  @override
  Future<ReportExportResult> share({
    required String baseName,
    required Uint8List csvBytes,
    required Uint8List xlsxBytes,
  }) async {
    this.baseName = baseName;
    this.csvBytes = csvBytes;
    this.xlsxBytes = xlsxBytes;
    return ReportExportResult(
      csvFileName: '$baseName.csv',
      xlsxFileName: '$baseName.xlsx',
    );
  }
}

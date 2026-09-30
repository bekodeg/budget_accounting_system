import 'dart:convert';

import 'package:budget_accounting_system/src/data/services/excel_report_document_encoder.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/period_report.dart';
import 'package:budget_accounting_system/src/domain/models/report_export.dart';
import 'package:budget_accounting_system/src/domain/models/report_filter.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final filter = ReportFilter(
    budgetId: 'budget-1',
    fromInclusive: DateTime(2026, 9),
    toExclusive: DateTime(2026, 10),
  );
  final bundle = ReportExportBundle(
    filter: filter,
    summary: PeriodReport(
      fromInclusive: filter.fromInclusive,
      toExclusive: filter.toExclusive,
      incomeMinorByCurrency: {'EUR': BigInt.from(100000)},
      expenseMinorByCurrency: {'EUR': BigInt.from(12550)},
      categories: [
        PeriodCategoryTotal(
          categoryId: 'food',
          categoryName: 'Еда',
          actualMinorByCurrency: {'EUR': BigInt.from(12550)},
        ),
      ],
    ),
    transactions: [
      ReportExportTransaction(
        id: 'tx-1',
        occurredAt: DateTime.utc(2026, 9, 5, 12, 30),
        amountMinor: BigInt.from(12550),
        currency: 'EUR',
        type: TransactionType.expense,
        authorId: 'user-1',
        accountId: 'card',
        destinationAccountId: null,
        categoryId: 'food',
        description: 'Кафе, "центр"',
      ),
    ],
  );

  test('CSV is UTF-8 with BOM, stable columns and escaped values', () {
    const encoder = ExcelReportDocumentEncoder();
    final bytes = encoder.encodeCsv(bundle);

    expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
    final csv = utf8.decode(bytes.sublist(3));

    expect(
      csv,
      contains(
        'transaction_id,occurred_at,type,amount_minor,amount_decimal,currency',
      ),
    );
    expect(csv, contains('tx-1'));
    expect(csv, contains('12550,125.50,EUR'));
    expect(csv, contains('"Кафе, ""центр"""'));
  });

  test('XLSX contains Summary, By Category and Transactions sheets', () {
    const encoder = ExcelReportDocumentEncoder();
    final bytes = encoder.encodeXlsx(bundle);
    final workbook = Excel.decodeBytes(bytes);

    expect(workbook.tables.keys, containsAll([
      'Summary',
      'By Category',
      'Transactions',
    ]));
    expect(workbook.tables['Transactions']!.maxRows, 2);
    expect(workbook.tables['By Category']!.maxRows, 2);
    expect(workbook.tables['Summary']!.maxRows, greaterThanOrEqualTo(4));
  });
}

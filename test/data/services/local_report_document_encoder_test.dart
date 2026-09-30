import 'dart:convert';

import 'package:budget_accounting_system/src/data/services/local_report_document_encoder.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/period_report.dart';
import 'package:budget_accounting_system/src/domain/models/report_export.dart';
import 'package:budget_accounting_system/src/domain/models/report_filter.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hugeAmount = BigInt.parse('900719925474099312345');

  ReportExportBundle bundle() {
    return ReportExportBundle(
      filter: ReportFilter(
        budgetId: 'budget-1',
        fromInclusive: DateTime(2026, 9),
        toExclusive: DateTime(2026, 10),
      ),
      summary: PeriodReport(
        fromInclusive: DateTime(2026, 9),
        toExclusive: DateTime(2026, 10),
        incomeMinorByCurrency: {'EUR': hugeAmount},
        expenseMinorByCurrency: {'EUR': BigInt.from(12345)},
        categories: [
          PeriodCategoryTotal(
            categoryId: 'food',
            categoryName: 'Еда',
            actualMinorByCurrency: {'EUR': BigInt.from(12345)},
          ),
        ],
      ),
      transactions: [
        ReportExportTransaction(
          id: 'tx-1',
          occurredAt: DateTime.utc(2026, 9, 15, 12, 30),
          amountMinor: hugeAmount,
          currency: 'EUR',
          type: TransactionType.expense,
          authorId: 'user-1',
          accountId: 'account-1',
          destinationAccountId: null,
          categoryId: 'food',
          description: 'Кафе, "утро"\nчек',
        ),
      ],
    );
  }

  test('CSV is UTF-8 and preserves exact minor units and escaping', () {
    const encoder = LocalReportDocumentEncoder();

    final csv = utf8.decode(encoder.encodeCsv(bundle()));

    expect(csv.startsWith('﻿transaction_id,occurred_at,type'), isTrue);
    expect(csv, contains(hugeAmount.toString()));
    expect(csv, contains('EXPENSE'));
    expect(csv, contains('"Кафе, ""утро""\nчек"'));
  });

  test('XLSX contains required sheets and exact text amounts', () {
    const encoder = LocalReportDocumentEncoder();

    final excel = Excel.decodeBytes(encoder.encodeXlsx(bundle()));

    expect(
      excel.sheets.keys,
      unorderedEquals(['Summary', 'By Category', 'Transactions']),
    );

    final summary = excel['Summary'];
    expect(_text(summary, 0, 0), 'metric');
    expect(_text(summary, 1, 0), 'income');
    expect(_text(summary, 1, 1), 'EUR');
    expect(_text(summary, 1, 2), hugeAmount.toString());

    final byCategory = excel['By Category'];
    expect(_text(byCategory, 0, 0), 'category_id');
    expect(_text(byCategory, 1, 0), 'food');
    expect(_text(byCategory, 1, 1), 'Еда');
    expect(_text(byCategory, 1, 2), 'EUR');
    expect(_text(byCategory, 1, 4), '12345');

    final transactions = excel['Transactions'];
    expect(_text(transactions, 0, 0), 'transaction_id');
    expect(_text(transactions, 1, 0), 'tx-1');
    expect(_text(transactions, 1, 3), hugeAmount.toString());
    expect(_text(transactions, 1, 9), 'Кафе, "утро"\nчек');
  });
}

String _text(Sheet sheet, int row, int column) {
  final value = sheet.rows[row][column]?.value;
  if (value is TextCellValue) {
    return value.value.text ?? '';
  }
  return value?.toString() ?? '';
}

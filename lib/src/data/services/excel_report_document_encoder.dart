import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../application/ports/report_document_encoder.dart';
import '../../domain/models/report_export.dart';

final class ExcelReportDocumentEncoder implements ReportDocumentEncoder {
  const ExcelReportDocumentEncoder();

  @override
  Uint8List encodeCsv(ReportExportBundle bundle) {
    final rows = <List<String>>[
      const [
        'transaction_id',
        'occurred_at',
        'type',
        'amount_minor',
        'amount_decimal',
        'currency',
        'author_id',
        'account_id',
        'destination_account_id',
        'category_id',
        'description',
      ],
      for (final transaction in bundle.transactions)
        [
          transaction.id,
          transaction.occurredAt.toIso8601String(),
          transaction.type.name.toUpperCase(),
          transaction.amountMinor.toString(),
          _decimalAmount(transaction.amountMinor),
          transaction.currency,
          transaction.authorId,
          transaction.accountId,
          transaction.destinationAccountId ?? '',
          transaction.categoryId ?? '',
          transaction.description ?? '',
        ],
    ];

    final content = rows
        .map((row) => row.map(_escapeCsv).join(','))
        .join('\r\n');
    return Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('$content\r\n'),
    ]);
  }

  @override
  Uint8List encodeXlsx(ReportExportBundle bundle) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Summary') {
      excel.rename(defaultSheet, 'Summary');
    }

    final summary = excel['Summary'];
    summary.appendRow(_cells(['Metric', 'Currency', 'Amount minor', 'Amount']));
    _appendCurrencyMap(summary, 'Income', bundle.summary.incomeMinorByCurrency);
    _appendCurrencyMap(
      summary,
      'Expense',
      bundle.summary.expenseMinorByCurrency,
    );
    _appendCurrencyMap(summary, 'Net', bundle.summary.netMinorByCurrency);

    final byCategory = excel['By Category'];
    byCategory.appendRow(
      _cells(['Category ID', 'Category', 'Currency', 'Actual minor', 'Actual']),
    );
    for (final category in bundle.summary.categories) {
      final entries = category.actualMinorByCurrency.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        byCategory.appendRow(
          _cells([
            category.categoryId ?? '',
            category.categoryName,
            entry.key,
            entry.value.toString(),
            _decimalAmount(entry.value),
          ]),
        );
      }
    }

    final transactions = excel['Transactions'];
    transactions.appendRow(
      _cells([
        'Transaction ID',
        'Occurred at',
        'Type',
        'Amount minor',
        'Amount',
        'Currency',
        'Author ID',
        'Account ID',
        'Destination account ID',
        'Category ID',
        'Description',
      ]),
    );
    for (final transaction in bundle.transactions) {
      transactions.appendRow(
        _cells([
          transaction.id,
          transaction.occurredAt.toIso8601String(),
          transaction.type.name.toUpperCase(),
          transaction.amountMinor.toString(),
          _decimalAmount(transaction.amountMinor),
          transaction.currency,
          transaction.authorId,
          transaction.accountId,
          transaction.destinationAccountId ?? '',
          transaction.categoryId ?? '',
          transaction.description ?? '',
        ]),
      );
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Unable to encode XLSX report.');
    }
    return Uint8List.fromList(bytes);
  }

  void _appendCurrencyMap(
    Sheet sheet,
    String metric,
    Map<String, BigInt> values,
  ) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      sheet.appendRow(
        _cells([
          metric,
          entry.key,
          entry.value.toString(),
          _decimalAmount(entry.value),
        ]),
      );
    }
  }
}

List<CellValue> _cells(List<String> values) =>
    values.map<CellValue>((value) => TextCellValue(value)).toList();

String _escapeCsv(String value) {
  if (!value.contains(RegExp(r'[,"\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

String _decimalAmount(BigInt minorUnits) {
  final negative = minorUnits.isNegative;
  final absolute = minorUnits.abs();
  final whole = absolute ~/ BigInt.from(100);
  final fraction = (absolute % BigInt.from(100)).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$whole.$fraction';
}

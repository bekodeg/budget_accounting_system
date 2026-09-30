import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../application/ports/report_document_encoder.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/report_export.dart';

final class LocalReportDocumentEncoder implements ReportDocumentEncoder {
  const LocalReportDocumentEncoder();

  @override
  Uint8List encodeCsv(ReportExportBundle bundle) {
    final output = StringBuffer('﻿');
    _writeCsvRow(output, const [
      'transaction_id',
      'occurred_at',
      'type',
      'amount_minor',
      'currency',
      'author_id',
      'account_id',
      'destination_account_id',
      'category_id',
      'description',
    ]);

    for (final transaction in bundle.transactions) {
      _writeCsvRow(output, [
        transaction.id,
        transaction.occurredAt.toIso8601String(),
        _typeLabel(transaction.type),
        transaction.amountMinor.toString(),
        transaction.currency,
        transaction.authorId,
        transaction.accountId,
        transaction.destinationAccountId ?? '',
        transaction.categoryId ?? '',
        transaction.description ?? '',
      ]);
    }

    return Uint8List.fromList(utf8.encode(output.toString()));
  }

  @override
  Uint8List encodeXlsx(ReportExportBundle bundle) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final summary = excel['Summary'];
    final categories = excel['By Category'];
    final transactions = excel['Transactions'];

    summary.appendRow(_textRow([
      'metric',
      'currency',
      'amount_minor',
    ]));
    _appendMetricRows(
      summary,
      'income',
      bundle.summary.incomeMinorByCurrency,
    );
    _appendMetricRows(
      summary,
      'expense',
      bundle.summary.expenseMinorByCurrency,
    );
    _appendMetricRows(
      summary,
      'net',
      bundle.summary.netMinorByCurrency,
    );

    categories.appendRow(_textRow([
      'category_id',
      'category_name',
      'currency',
      'planned_minor',
      'actual_minor',
      'remaining_minor',
    ]));
    for (final category in bundle.summary.categories) {
      final currencies = <String>{
        ...category.actualMinorByCurrency.keys,
      }.toList()
        ..sort();
      if (currencies.isEmpty) {
        categories.appendRow(
          _textRow([
            category.categoryId ?? '',
            category.categoryName,
            '',
            '',
            '',
            '',
          ]),
        );
      } else {
        for (final currency in currencies) {
          categories.appendRow(
            _textRow([
              category.categoryId ?? '',
              category.categoryName,
              currency,
              '',
              category.actualMinorByCurrency[currency]!.toString(),
              '',
            ]),
          );
        }
      }
    }

    transactions.appendRow(_textRow([
      'transaction_id',
      'occurred_at',
      'type',
      'amount_minor',
      'currency',
      'author_id',
      'account_id',
      'destination_account_id',
      'category_id',
      'description',
    ]));
    for (final transaction in bundle.transactions) {
      transactions.appendRow(
        _textRow([
          transaction.id,
          transaction.occurredAt.toIso8601String(),
          _typeLabel(transaction.type),
          transaction.amountMinor.toString(),
          transaction.currency,
          transaction.authorId,
          transaction.accountId,
          transaction.destinationAccountId ?? '',
          transaction.categoryId ?? '',
          transaction.description ?? '',
        ]),
      );
    }

    if (defaultSheet != null &&
        defaultSheet != 'Summary' &&
        defaultSheet != 'By Category' &&
        defaultSheet != 'Transactions') {
      excel.delete(defaultSheet);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode XLSX report.');
    }
    return Uint8List.fromList(bytes);
  }

  void _appendMetricRows(
    Sheet sheet,
    String metric,
    Map<String, BigInt> values,
  ) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      sheet.appendRow(
        _textRow([metric, entry.key, entry.value.toString()]),
      );
    }
  }

  List<CellValue?> _textRow(List<String> values) {
    return values.map<CellValue?>((value) => TextCellValue(value)).toList();
  }

  void _writeCsvRow(StringBuffer output, List<String> values) {
    output
      ..writeln(values.map(_escapeCsv).join(','));
  }

  String _escapeCsv(String value) {
    if (!value.contains(',') &&
        !value.contains('"') &&
        !value.contains('\n') &&
        !value.contains('\r')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  String _typeLabel(TransactionType type) {
    return switch (type) {
      TransactionType.income => 'INCOME',
      TransactionType.expense => 'EXPENSE',
      TransactionType.transfer => 'TRANSFER',
    };
  }
}

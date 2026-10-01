import 'package:budget_accounting_system/src/application/services/receipt_ocr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ReceiptOcrParser();

  test('extracts merchant date and total from common receipt text', () {
    final result = parser.parse(
      'Coffee Shop\n30.09.2026 12:45\nLatte 4.50\nИТОГО 12,50',
    );

    expect(result.merchant, 'Coffee Shop');
    expect(result.occurredAt, DateTime(2026, 9, 30, 12, 45));
    expect(result.totalMinor, BigInt.from(1250));
    expect(result.parseStatus, 'PARSED');
    expect(result.parsedPayloadJson, contains('"source":"ocr"'));
  });

  test('partial recognition remains editable', () {
    final result = parser.parse('Market\nThank you');
    expect(result.merchant, 'Market');
    expect(result.totalMinor, isNull);
    expect(result.parseStatus, 'PARTIAL');
  });

  test('empty OCR result is failed', () {
    final result = parser.parse('');
    expect(result.parseStatus, 'FAILED');
  });
}

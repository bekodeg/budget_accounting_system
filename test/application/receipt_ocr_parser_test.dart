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
    expect(result.items, hasLength(1));
    expect(result.items.single.name, 'Latte');
    expect(result.items.single.lineTotalMinor, BigInt.from(450));
  });

  test('extracts detailed items and excludes totals and payments', () {
    final result = parser.parse(
      'Market\n30.09.2026 12:45\nMilk 2 x 3.50 7.00\n'
      'Bread 2.50\nTOTAL 9.50\nCASH 10.00\nCHANGE 0.50',
    );

    expect(result.items, hasLength(2));
    expect(result.items.first.name, 'Milk');
    expect(result.items.first.quantity, 2);
    expect(result.items.first.unitPriceMinor, BigInt.from(350));
    expect(result.items.first.lineTotalMinor, BigInt.from(700));
    expect(result.items.last.name, 'Bread');
    expect(result.items.last.lineTotalMinor, BigInt.from(250));
  });

  test('partial recognition remains editable', () {
    final result = parser.parse('Market\nThank you');
    expect(result.merchant, 'Market');
    expect(result.totalMinor, isNull);
    expect(result.parseStatus, 'PARTIAL');
    expect(result.items, isEmpty);
  });

  test('misread total and merged tax columns are not receipt items', () {
    final result = parser.parse(
      'Shop\n30.10.2026 09:59\n'
      'A НМН.УМЬАНКА H 22% 38.99 1 38.99\n'
      'WТОГ 108.98',
    );

    expect(result.totalMinor, BigInt.from(10898));
    expect(result.items, isEmpty);
  });

  test('a product percentage does not hide a valid item', () {
    final result = parser.parse('Shop\nYogurt 2.5% 38.99');
    expect(result.items.single.name, 'Yogurt 2.5%');
  });

  test('empty OCR result is failed', () {
    final result = parser.parse('');
    expect(result.parseStatus, 'FAILED');
    expect(result.items, isEmpty);
  });
}

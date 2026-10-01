import 'package:budget_accounting_system/src/application/services/fiscal_receipt_qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FiscalReceiptQrParser();

  test('parses fiscal date amount and optional merchant offline', () {
    final result = parser.parse(
      't=20260930T1913&s=349.50&fn=123&i=42&fp=777&merchant=Market',
    );

    expect(result.occurredAt, DateTime(2026, 9, 30, 19, 13));
    expect(result.totalMinor, BigInt.from(34950));
    expect(result.merchant, 'Market');
    expect(result.parseStatus, 'PARSED');
    expect(result.parsedPayloadJson, contains('"fn":"123"'));
  });

  test('unknown QR stays usable as manual NEW draft', () {
    final result = parser.parse('hello-world');

    expect(result.rawQr, 'hello-world');
    expect(result.occurredAt, isNull);
    expect(result.totalMinor, isNull);
    expect(result.merchant, isNull);
    expect(result.parseStatus, 'NEW');
  });

  test('supports partial locally parsable QR', () {
    final result = parser.parse('s=10,05');

    expect(result.totalMinor, BigInt.from(1005));
    expect(result.occurredAt, isNull);
    expect(result.parseStatus, 'PARTIAL');
  });
}

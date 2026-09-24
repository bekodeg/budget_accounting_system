import 'package:budget_accounting_system/src/application/formatters/minor_units_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses decimal amount to minor units', () {
    expect(parseMinorUnitsText('1250.50'), BigInt.from(125050));
    expect(parseMinorUnitsText('  -10,25 '), BigInt.from(-1025));
    expect(parseMinorUnitsText('0'), BigInt.zero);
  });

  test('rejects more than two fraction digits by default', () {
    expect(() => parseMinorUnitsText('1.234'), throwsA(isA<FormatException>()));
  });

  test('formats signed minor units', () {
    expect(formatMinorUnits(BigInt.from(125050)), '1250.50');
    expect(formatMinorUnits(BigInt.from(-1025)), '-10.25');
    expect(formatMinorUnits(BigInt.zero), '0.00');
  });
}

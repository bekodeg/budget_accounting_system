import 'dart:math';

import 'package:budget_accounting_system/src/data/services/secure_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates UUID v4 shaped identifiers', () {
    final generator = SecureIdGenerator(random: Random(42));

    final first = generator.nextId();
    final second = generator.nextId();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, isNot(first));
  });
}

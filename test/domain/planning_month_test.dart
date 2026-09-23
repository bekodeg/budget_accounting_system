import 'package:budget_accounting_system/src/domain/value_objects/planning_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes any date to the first day of its month', () {
    final month = PlanningMonth(DateTime(2026, 9, 23, 18, 45));

    expect(month.value, DateTime(2026, 9));
    expect(month.year, 2026);
    expect(month.month, 9);
    expect(month.toString(), '2026-09');
  });
}

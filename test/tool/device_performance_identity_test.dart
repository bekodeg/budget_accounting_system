import 'package:flutter_test/flutter_test.dart';

import '../../tool/device_performance_main.dart';

void main() {
  test('performance seed accepts only the isolated Android package', () {
    expect(
      () => verifyPerformancePackage(performancePackageId),
      returnsNormally,
    );
    expect(
      () => verifyPerformancePackage('com.bekodeg.budget_accounting_system'),
      throwsStateError,
    );
    expect(() => verifyPerformancePackage(null), throwsStateError);
  });
}

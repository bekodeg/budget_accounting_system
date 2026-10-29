import 'package:budget_accounting_system/src/presentation/report_charts/report_chart_data.dart';
import 'package:budget_accounting_system/src/presentation/report_charts/report_chart_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('many categories remain readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final categories = [
      for (var index = 0; index < 20; index++)
        CategoryExpenseValue(
          id: 'category-$index',
          name: 'Очень длинное название категории расходов $index',
          amountMinor: BigInt.from((index + 1) * 100),
        ),
    ];
    final planFact = [
      for (final category in categories)
        CategoryPlanFactValue(
          id: category.id,
          name: category.name,
          planMinor: category.amountMinor * BigInt.from(2),
          actualMinor: category.amountMinor,
        ),
    ];
    final months = [
      for (var month = 1; month <= 12; month++)
        MonthExpenseValue(
          month: month,
          amountMinor: month == 1 ? BigInt.from(1000) : BigInt.zero,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ExpensePieChart(
                key: const ValueKey('pie'),
                title: 'Расходы по категориям',
                currency: 'EUR',
                values: categories,
              ),
              PlanFactColumnChart(
                key: const ValueKey('plan-fact'),
                currency: 'EUR',
                values: planFact,
              ),
              MonthExpenseColumnChart(
                key: const ValueKey('months'),
                currency: 'EUR',
                values: months,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('категории расходов 0'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('plan-fact')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('months')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('report-chart-month-12')), findsOneWidget);
  });
}

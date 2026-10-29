import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/formatters/minor_units_text.dart';
import 'report_chart_data.dart';

const _pieColors = <Color>[
  Color(0xFF1565C0),
  Color(0xFFD84315),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
  Color(0xFFAD1457),
  Color(0xFF5D4037),
  Color(0xFF827717),
];

final class ReportCurrencySelector extends StatelessWidget {
  const ReportCurrencySelector({
    required this.currencies,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> currencies;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Валюта расходов: '),
      const SizedBox(width: 8),
      DropdownButton<String>(
        key: const ValueKey('report-chart-currency'),
        value: selected,
        items: [
          for (final currency in currencies)
            DropdownMenuItem(value: currency, child: Text(currency)),
        ],
        onChanged: (currency) {
          if (currency != null) onChanged(currency);
        },
      ),
    ],
  );
}

final class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({
    required this.title,
    required this.currency,
    required this.values,
    super.key,
  });

  final String title;
  final String currency;
  final List<CategoryExpenseValue> values;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<BigInt>(
      BigInt.zero,
      (sum, value) => sum + value.amountMinor,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Фактические расходы · $currency'),
            const SizedBox(height: 12),
            if (total == BigInt.zero)
              Text('Нет расходов в $currency за выбранный период.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final pie = Semantics(
                    label: 'Круговая диаграмма расходов в $currency',
                    child: SizedBox.square(
                      dimension: 160,
                      child: CustomPaint(
                        painter: _ExpensePiePainter(
                          values: values,
                          total: total,
                        ),
                      ),
                    ),
                  );
                  final legend = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < values.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: _pieColors[index % _pieColors.length],
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${values[index].name}: '
                                  '${formatMinorUnits(values[index].amountMinor)} '
                                  '$currency (${_sharePercent(values[index].amountMinor, total)}%)',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [pie, const SizedBox(height: 16), legend],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pie,
                      const SizedBox(width: 20),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

final class PlanFactColumnChart extends StatelessWidget {
  const PlanFactColumnChart({
    required this.values,
    required this.currency,
    super.key,
  });

  final List<CategoryPlanFactValue> values;
  final String currency;

  @override
  Widget build(BuildContext context) {
    var maximum = BigInt.zero;
    for (final value in values) {
      if (value.planMinor > maximum) maximum = value.planMinor;
      if (value.actualMinor > maximum) maximum = value.actualMinor;
    }
    final planColor = Theme.of(context).colorScheme.primary;
    final actualColor = Theme.of(context).colorScheme.tertiary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'План / факт по категориям',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Сравнение только в базовой валюте · $currency'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                _LegendItem(color: planColor, label: 'План'),
                _LegendItem(color: actualColor, label: 'Факт'),
              ],
            ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Text('Нет категорий с планом или расходами.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final value in values)
                      SizedBox(
                        width: 132,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 116,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _ColumnBar(
                                      value: value.planMinor,
                                      maximum: maximum,
                                      color: planColor,
                                    ),
                                    const SizedBox(width: 8),
                                    _ColumnBar(
                                      value: value.actualMinor,
                                      maximum: maximum,
                                      color: actualColor,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Tooltip(
                                message: value.name,
                                child: Text(
                                  value.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Text(
                                'П ${formatMinorUnits(value.planMinor)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Ф ${formatMinorUnits(value.actualMinor)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class MonthExpenseColumnChart extends StatelessWidget {
  const MonthExpenseColumnChart({
    required this.values,
    required this.currency,
    super.key,
  });

  final List<MonthExpenseValue> values;
  final String currency;

  @override
  Widget build(BuildContext context) {
    var maximum = BigInt.zero;
    for (final value in values) {
      if (value.amountMinor > maximum) maximum = value.amountMinor;
    }
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Расходы по месяцам',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Фактические расходы · $currency'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final value in values)
                    SizedBox(
                      key: ValueKey('report-chart-month-${value.month}'),
                      width: 76,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 116,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: _ColumnBar(
                                value: value.amountMinor,
                                maximum: maximum,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_shortMonthName(value.month)),
                          Text(
                            formatMinorUnits(value.amountMinor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}

final class _ColumnBar extends StatelessWidget {
  const _ColumnBar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  final BigInt value;
  final BigInt maximum;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 28, height: _barHeight(value, maximum), color: color);
}

final class _ExpensePiePainter extends CustomPainter {
  const _ExpensePiePainter({required this.values, required this.total});

  final List<CategoryExpenseValue> values;
  final BigInt total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = 2 * math.pi * _ratio(values[index].amountMinor, total);
      paint.color = _pieColors[index % _pieColors.length];
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpensePiePainter oldDelegate) =>
      oldDelegate.total != total || oldDelegate.values != values;
}

double _ratio(BigInt value, BigInt total) {
  if (value <= BigInt.zero || total <= BigInt.zero) return 0;
  return ((value * BigInt.from(1000000)) ~/ total).toDouble() / 1000000;
}

double _barHeight(BigInt value, BigInt maximum) =>
    maximum <= BigInt.zero || value <= BigInt.zero
    ? 0
    : 114 * _ratio(value, maximum);

String _sharePercent(BigInt value, BigInt total) =>
    (100 * _ratio(value, total)).toStringAsFixed(1);

String _shortMonthName(int month) => const [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
][month - 1];

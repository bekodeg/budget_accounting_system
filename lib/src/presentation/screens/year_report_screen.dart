import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/year_report.dart';

final class YearReportScreen extends StatefulWidget {
  const YearReportScreen({
    required this.services,
    required this.budgetId,
    this.initialYear,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final int? initialYear;

  @override
  State<YearReportScreen> createState() => _YearReportScreenState();
}

final class _YearReportScreenState extends State<YearReportScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<YearReport>(
      stream: widget.services.watchYearReport(
        budgetId: widget.budgetId,
        year: _year,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось построить годовой отчет.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = snapshot.data!;
        final isEmpty =
            report.incomeMinorByCurrency.isEmpty &&
            report.expenseMinorByCurrency.isEmpty &&
            report.plannedAmountMinor == BigInt.zero;

        return ListView(
          key: const ValueKey('year-report-screen'),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('year-report-previous'),
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_year}',
                    key: const ValueKey('year-report-year'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('year-report-next'),
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CurrencySummary(
              income: report.incomeMinorByCurrency,
              expense: report.expenseMinorByCurrency,
              net: report.netMinorByCurrency,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('План / факт за год'),
                subtitle: Text(
                  'План: ${formatMinorUnits(report.plannedAmountMinor)} '
                  '${report.baseCurrency}\n'
                  'Факт: ${formatMinorUnits(report.actualBaseCurrencyMinor)} '
                  '${report.baseCurrency}',
                ),
                trailing: Text(
                  formatMinorUnits(report.varianceMinor),
                  key: const ValueKey('year-report-variance'),
                ),
              ),
            ),
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('За этот год данных пока нет.')),
              )
            else ...[
              const SizedBox(height: 20),
              Text(
                'По месяцам',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final month in report.months)
                _YearMonthTile(month: month, baseCurrency: report.baseCurrency),
              if (report.categories.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'По категориям',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final category in report.categories)
                  _YearCategoryTile(category: category),
              ],
            ],
          ],
        );
      },
    );
  }
}

final class _CurrencySummary extends StatelessWidget {
  const _CurrencySummary({
    required this.income,
    required this.expense,
    required this.net,
  });

  final Map<String, BigInt> income;
  final Map<String, BigInt> expense;
  final Map<String, BigInt> net;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ValuesCard(label: 'Доход', values: income),
        _ValuesCard(label: 'Расход', values: expense),
        _ValuesCard(label: 'Cash flow', values: net),
      ],
    );
  }
}

final class _ValuesCard extends StatelessWidget {
  const _ValuesCard({required this.label, required this.values});

  final String label;
  final Map<String, BigInt> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 130),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 4),
              if (entries.isEmpty)
                const Text('0.00')
              else
                for (final entry in entries)
                  Text('${formatMinorUnits(entry.value)} ${entry.key}'),
            ],
          ),
        ),
      ),
    );
  }
}

final class _YearMonthTile extends StatelessWidget {
  const _YearMonthTile({required this.month, required this.baseCurrency});

  final YearMonthReport month;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    final hasData =
        month.incomeMinorByCurrency.isNotEmpty ||
        month.expenseMinorByCurrency.isNotEmpty ||
        month.plannedAmountMinor != BigInt.zero;
    return ListTile(
      key: ValueKey('year-month-${month.monthStart.month}'),
      contentPadding: EdgeInsets.zero,
      title: Text(_monthName(month.monthStart.month)),
      subtitle: hasData
          ? Text(
              'План: ${formatMinorUnits(month.plannedAmountMinor)} '
              '${baseCurrency} · '
              'Факт: ${formatMinorUnits(month.actualBaseCurrencyMinor)} '
              '${baseCurrency}',
            )
          : const Text('Нет данных'),
      trailing: hasData
          ? Text('${formatMinorUnits(month.varianceMinor)} ${baseCurrency}')
          : null,
    );
  }
}

final class _YearCategoryTile extends StatelessWidget {
  const _YearCategoryTile({required this.category});

  final YearCategoryReport category;

  @override
  Widget build(BuildContext context) {
    final actual = category.actualMinorByCurrency.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final actualLabel = actual.isEmpty
        ? '0.00'
        : actual
              .map((entry) => '${formatMinorUnits(entry.value)} ${entry.key}')
              .join(', ');
    return ListTile(
      key: ValueKey('year-category-${category.categoryId ?? 'uncategorized'}'),
      contentPadding: EdgeInsets.zero,
      title: Text(category.categoryName),
      subtitle: Text(
        'План: ${formatMinorUnits(category.plannedAmountMinor)} '
        '${category.planCurrency} · Факт: ${actualLabel}',
      ),
      trailing: Text(
        '${formatMinorUnits(category.varianceMinor)} ${category.planCurrency}',
      ),
    );
  }
}

String _monthName(int month) {
  const names = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return names[month - 1];
}

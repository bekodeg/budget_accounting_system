import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/monthly_report.dart';

final class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({
    required this.services,
    required this.budgetId,
    this.initialMonth,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final DateTime? initialMonth;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

final class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final value = widget.initialMonth ?? DateTime.now();
    _month = DateTime(value.year, value.month);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MonthlyReport>(
      stream: widget.services.watchMonthlyReport(
        budgetId: widget.budgetId,
        month: _month,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось построить месячный отчет.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = snapshot.data!;
        return ListView(
          key: const ValueKey('monthly-report-screen'),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('report-previous-month'),
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _monthLabel(report.monthStart),
                    key: const ValueKey('report-month-label'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('report-next-month'),
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricCard(
                  key: const ValueKey('report-income'),
                  label: 'Доход',
                  values: report.incomeMinorByCurrency,
                ),
                _MetricCard(
                  key: const ValueKey('report-expense'),
                  label: 'Расход',
                  values: report.expenseMinorByCurrency,
                ),
                _MetricCard(
                  key: const ValueKey('report-net'),
                  label: 'Cash flow',
                  values: report.netMinorByCurrency,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'План / факт по категориям',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (report.categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('За этот месяц нет планов и расходов по категориям.'),
              )
            else
              for (final category in report.categories)
                _CategoryReportTile(category: category),
            const SizedBox(height: 24),
            Text(
              'Остатки счетов на конец месяца',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (report.accountBalances.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Счетов пока нет.'),
              )
            else
              for (final account in report.accountBalances)
                ListTile(
                  key: ValueKey('report-account-${account.accountId}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(account.accountName),
                  subtitle: account.isArchived
                      ? const Text('Архивный счет')
                      : null,
                  trailing: Text(
                    '${formatMinorUnits(account.balance.minorUnits)} '
                    '${account.balance.currency.code}',
                  ),
                ),
          ],
        );
      },
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.values,
    super.key,
  });

  final String label;
  final Map<String, BigInt> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 140),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 6),
              if (entries.isEmpty)
                const Text('0.00')
              else
                for (final entry in entries)
                  Text(
                    '${formatMinorUnits(entry.value)} ${entry.key}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _CategoryReportTile extends StatelessWidget {
  const _CategoryReportTile({required this.category});

  final MonthlyCategoryReport category;

  @override
  Widget build(BuildContext context) {
    final actualEntries = category.actualMinorByCurrency.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final actualText = actualEntries.isEmpty
        ? '0.00 ${category.planCurrency}'
        : actualEntries
              .map(
                (entry) =>
                    '${formatMinorUnits(entry.value)} ${entry.key}',
              )
              .join(', ');

    return Card(
      key: ValueKey(
        'report-category-${category.categoryId ?? 'uncategorized'}',
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.categoryName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'План: ${formatMinorUnits(category.plannedAmountMinor)} '
              '${category.planCurrency}',
            ),
            Text('Факт: $actualText'),
            Text(
              'Остаток: ${formatMinorUnits(category.remainingMinor)} '
              '${category.planCurrency}',
              key: ValueKey(
                'report-category-remaining-'
                '${category.categoryId ?? 'uncategorized'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _monthLabel(DateTime month) {
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
  return '${names[month.month - 1]} ${month.year}';
}

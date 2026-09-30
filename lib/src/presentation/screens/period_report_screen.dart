import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/budget_account.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/period_report.dart';
import '../../domain/models/report_filter.dart';

final class PeriodReportScreen extends StatefulWidget {
  const PeriodReportScreen({
    required this.services,
    required this.budgetId,
    required this.userId,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final String userId;

  @override
  State<PeriodReportScreen> createState() => _PeriodReportScreenState();
}

final class _PeriodReportScreenState extends State<PeriodReportScreen> {
  late DateTime _fromInclusive;
  late DateTime _toExclusive;
  final Set<String> _categoryIds = {};
  final Set<String> _accountIds = {};
  bool _onlyMine = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromInclusive = DateTime(now.year, now.month);
    _toExclusive = DateTime(now.year, now.month + 1);
  }

  ReportFilter get _filter => ReportFilter(
    budgetId: widget.budgetId,
    fromInclusive: _fromInclusive,
    toExclusive: _toExclusive,
    categoryIds: _categoryIds,
    accountIds: _accountIds,
    authorIds: _onlyMine ? {widget.userId} : const {},
  );

  Future<void> _pickFrom() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _fromInclusive,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value == null || !mounted) return;
    if (!value.isBefore(_toExclusive)) {
      _showMessage('Дата начала должна быть раньше верхней границы.');
      return;
    }
    setState(() => _fromInclusive = value);
  }

  Future<void> _pickTo() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _toExclusive,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value == null || !mounted) return;
    if (!_fromInclusive.isBefore(value)) {
      _showMessage('Верхняя граница должна быть позже даты начала.');
      return;
    }
    setState(() => _toExclusive = value);
  }

  Future<void> _export() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      final result = await widget.services.exportReport(_filter);
      if (mounted) {
        _showMessage(
          'Подготовлены ${result.csvFileName} и ${result.xlsxFileName}.',
        );
      }
    } on Object {
      if (mounted) {
        _showMessage('Не удалось экспортировать отчет.');
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetCategory>>(
      stream: widget.services.watchBudgetCategories(
        widget.budgetId,
        includeArchived: true,
      ),
      builder: (context, categorySnapshot) {
        if (categorySnapshot.hasError) {
          return const Center(child: Text('Не удалось загрузить категории.'));
        }
        if (!categorySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<List<BudgetAccount>>(
          stream: widget.services.watchBudgetAccounts(
            widget.budgetId,
            includeArchived: true,
          ),
          builder: (context, accountSnapshot) {
            if (accountSnapshot.hasError) {
              return const Center(child: Text('Не удалось загрузить счета.'));
            }
            if (!accountSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildReport(
              context,
              categorySnapshot.data!,
              accountSnapshot.data!,
            );
          },
        );
      },
    );
  }

  Widget _buildReport(
    BuildContext context,
    List<BudgetCategory> categories,
    List<BudgetAccount> accounts,
  ) {
    return StreamBuilder<PeriodReport>(
      stream: widget.services.watchPeriodReport(_filter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось построить отчет за период.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final report = snapshot.data!;
        final isEmpty =
            report.incomeMinorByCurrency.isEmpty &&
            report.expenseMinorByCurrency.isEmpty;

        return ListView(
          key: const ValueKey('period-report-screen'),
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  key: const ValueKey('period-from'),
                  onPressed: _pickFrom,
                  child: Text('С: ${_dateLabel(_fromInclusive)}'),
                ),
                OutlinedButton(
                  key: const ValueKey('period-to'),
                  onPressed: _pickTo,
                  child: Text('До: ${_dateLabel(_toExclusive)} (не включая)'),
                ),
                FilterChip(
                  key: const ValueKey('period-only-mine'),
                  label: const Text('Только мои'),
                  selected: _onlyMine,
                  onSelected: (value) => setState(() => _onlyMine = value),
                ),
                FilledButton.icon(
                  key: const ValueKey('period-export'),
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_outlined),
                  label: const Text('CSV/XLSX'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Категории', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in categories)
                  FilterChip(
                    key: ValueKey('period-category-${category.id}'),
                    label: Text(category.name),
                    selected: _categoryIds.contains(category.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _categoryIds.add(category.id);
                        } else {
                          _categoryIds.remove(category.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Счета', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final account in accounts)
                  FilterChip(
                    key: ValueKey('period-account-${account.id}'),
                    label: Text(account.name),
                    selected: _accountIds.contains(account.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _accountIds.add(account.id);
                        } else {
                          _accountIds.remove(account.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _PeriodMetric(label: 'Доход', values: report.incomeMinorByCurrency),
            _PeriodMetric(
              label: 'Расход',
              values: report.expenseMinorByCurrency,
            ),
            _PeriodMetric(
              label: 'Cash flow',
              values: report.netMinorByCurrency,
            ),
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Для выбранного периода и фильтров данных нет.'),
                ),
              )
            else if (report.categories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Расходы по категориям',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final category in report.categories)
                ListTile(
                  key: ValueKey(
                    'period-category-total-'
                    '${category.categoryId ?? 'uncategorized'}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  title: Text(category.categoryName),
                  trailing: Text(_valuesLabel(category.actualMinorByCurrency)),
                ),
            ],
          ],
        );
      },
    );
  }
}

final class _PeriodMetric extends StatelessWidget {
  const _PeriodMetric({required this.label, required this.values});

  final String label;
  final Map<String, BigInt> values;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(_valuesLabel(values)),
    );
  }
}

String _valuesLabel(Map<String, BigInt> values) {
  final entries = values.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (entries.isEmpty) return '0.00';
  return entries
      .map((entry) => '${formatMinorUnits(entry.value)} ${entry.key}')
      .join(', ');
}

String _dateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/dashboard_summary.dart';
import 'transaction_crud_screen.dart';
import 'transaction_editor_screen.dart';

final class BudgetDashboardScreen extends StatelessWidget {
  const BudgetDashboardScreen({
    required this.services,
    required this.budgetId,
    required this.userId,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final String userId;

  Future<void> _quickAdd(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TransactionEditorScreen(
          services: services,
          budgetId: budgetId,
          authorId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      key: const ValueKey('budget-dashboard'),
      children: [
        StreamBuilder<DashboardSummary>(
          stream: services.watchDashboardSummary(
            budgetId: budgetId,
            month: now,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Не удалось рассчитать показатели бюджета.'),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }

            return _DashboardHeader(
              summary: snapshot.data!,
              onQuickAdd: () => _quickAdd(context),
            );
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: TransactionCrudScreen(
            services: services,
            budgetId: budgetId,
            userId: userId,
          ),
        ),
      ],
    );
  }
}

final class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.summary, required this.onQuickAdd});

  final DashboardSummary summary;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthLabel(summary.monthStart),
                  key: const ValueKey('dashboard-month'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('dashboard-quick-add'),
                onPressed: onQuickAdd,
                icon: const Icon(Icons.add),
                label: const Text('Операция'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MetricCard(
                  key: const ValueKey('dashboard-income'),
                  label: 'Доход',
                  icon: Icons.trending_up,
                  values: summary.incomeMinorByCurrency,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  key: const ValueKey('dashboard-expense'),
                  label: 'Расход',
                  icon: Icons.trending_down,
                  values: summary.expenseMinorByCurrency,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  key: const ValueKey('dashboard-net'),
                  label: 'Cash flow',
                  icon: Icons.swap_vert,
                  values: summary.netMinorByCurrency,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  key: const ValueKey('dashboard-balance'),
                  label: 'Доступно',
                  icon: Icons.account_balance_wallet_outlined,
                  values: summary.balanceMinorByCurrency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.icon,
    required this.values,
    super.key,
  });

  final String label;
  final IconData icon;
  final Map<String, BigInt> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
              const SizedBox(height: 8),
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

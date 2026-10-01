import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/plan_error.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/monthly_plan.dart';

final class MonthlyPlanScreen extends StatefulWidget {
  const MonthlyPlanScreen({
    required this.services,
    required this.budgetId,
    this.canEdit = true,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final bool canEdit;

  @override
  State<MonthlyPlanScreen> createState() => _MonthlyPlanScreenState();
}

final class _MonthlyPlanScreenState extends State<MonthlyPlanScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = normalizePlanMonth(DateTime.now());
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _edit(BudgetCategory category, BigInt currentAmount) async {
    final raw = await showDialog<String>(
      context: context,
      builder: (context) =>
          _PlanAmountDialog(category: category, currentAmount: currentAmount),
    );
    if (raw == null || !mounted) return;

    try {
      final amount = parseMinorUnitsText(raw);
      await widget.services.setMonthlyPlanAmount(
        budgetId: widget.budgetId,
        categoryId: category.id,
        month: _month,
        plannedAmountMinor: amount,
      );
    } on PlanError catch (error) {
      if (mounted) _showMessage(error.message);
    } on FormatException {
      if (mounted) _showMessage('Введите корректную сумму.');
    } on Object {
      if (mounted) _showMessage('Не удалось сохранить план.');
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

        return StreamBuilder<List<MonthlyPlan>>(
          stream: widget.services.watchMonthlyPlan(
            budgetId: widget.budgetId,
            month: _month,
          ),
          builder: (context, planSnapshot) {
            if (planSnapshot.hasError) {
              return const Center(child: Text('Не удалось загрузить план.'));
            }
            if (!planSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final categories = categorySnapshot.data!;
            final plans = planSnapshot.data!;
            final plansByCategory = {
              for (final plan in plans) plan.categoryId: plan,
            };
            final active = categories
                .where(
                  (category) =>
                      !category.isArchived &&
                      category.kind != CategoryKind.income,
                )
                .toList(growable: false);
            final historical = categories
                .where(
                  (category) =>
                      category.isArchived &&
                      plansByCategory.containsKey(category.id),
                )
                .toList(growable: false);
            final total = plans.fold<BigInt>(
              BigInt.zero,
              (sum, plan) => sum + plan.plannedAmountMinor,
            );

            return ListView(
              key: const ValueKey('monthly-plan-screen'),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('plan-previous-month'),
                      onPressed: () => _moveMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_month),
                        key: const ValueKey('plan-month-label'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('plan-next-month'),
                      onPressed: () => _moveMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('План на месяц'),
                    trailing: Text(
                      formatMinorUnits(total),
                      key: const ValueKey('plan-total'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (active.isEmpty && historical.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Нет расходных категорий для планирования.'),
                    ),
                  ),
                for (final category in active)
                  _PlanCategoryTile(
                    category: category,
                    amount:
                        plansByCategory[category.id]?.plannedAmountMinor ??
                        BigInt.zero,
                    editable: widget.canEdit,
                    onTap: widget.canEdit
                        ? () => _edit(
                            category,
                            plansByCategory[category.id]?.plannedAmountMinor ??
                                BigInt.zero,
                          )
                        : null,
                  ),
                if (historical.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Архивные категории',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final category in historical)
                    _PlanCategoryTile(
                      category: category,
                      amount: plansByCategory[category.id]!.plannedAmountMinor,
                      editable: false,
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

final class _PlanCategoryTile extends StatelessWidget {
  const _PlanCategoryTile({
    required this.category,
    required this.amount,
    required this.editable,
    this.onTap,
  });

  final BudgetCategory category;
  final BigInt amount;
  final bool editable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('plan-category-${category.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(category.name),
      subtitle: editable
          ? null
          : const Text('Архивная категория — только история'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatMinorUnits(amount)),
          if (editable) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined),
          ],
        ],
      ),
      onTap: editable ? onTap : null,
    );
  }
}

final class _PlanAmountDialog extends StatefulWidget {
  const _PlanAmountDialog({
    required this.category,
    required this.currentAmount,
  });

  final BudgetCategory category;
  final BigInt currentAmount;

  @override
  State<_PlanAmountDialog> createState() => _PlanAmountDialogState();
}

final class _PlanAmountDialogState extends State<_PlanAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: formatMinorUnits(widget.currentAmount),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category.name),
      content: TextField(
        key: const ValueKey('plan-amount-input'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Плановая сумма',
          helperText: '0 очищает план',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('save-plan-amount'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Сохранить'),
        ),
      ],
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

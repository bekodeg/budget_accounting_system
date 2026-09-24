import 'package:flutter/material.dart';

import '../../domain/models/budget_summary.dart';

typedef SelectBudgetCallback = Future<void> Function(String budgetId);

final class BudgetSelectionScreen extends StatefulWidget {
  const BudgetSelectionScreen({
    required this.budgets,
    required this.onSelect,
    super.key,
  });

  final List<BudgetSummary> budgets;
  final SelectBudgetCallback onSelect;

  @override
  State<BudgetSelectionScreen> createState() => _BudgetSelectionScreenState();
}

final class _BudgetSelectionScreenState extends State<BudgetSelectionScreen> {
  String? _selectingBudgetId;
  String? _errorMessage;

  Future<void> _select(String budgetId) async {
    if (_selectingBudgetId != null) {
      return;
    }

    setState(() {
      _selectingBudgetId = budgetId;
      _errorMessage = null;
    });

    try {
      await widget.onSelect(budgetId);
    } on Object {
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось выбрать бюджет. Повторите попытку.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectingBudgetId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите бюджет')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final budget in widget.budgets)
            Card(
              child: ListTile(
                key: ValueKey('budget-${budget.id}'),
                title: Text(budget.name),
                subtitle: Text(budget.baseCurrency),
                trailing: _selectingBudgetId == budget.id
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _selectingBudgetId == null
                    ? () => _select(budget.id)
                    : null,
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                key: const ValueKey('budget-selection-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

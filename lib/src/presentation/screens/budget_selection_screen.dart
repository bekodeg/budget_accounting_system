import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/onboarding_error.dart';
import '../../domain/models/budget_summary.dart';
import '../../domain/errors/domain_validation_error.dart';
import '../../domain/value_objects/currency.dart';
import 'budget_invite_panel.dart';

typedef SelectBudgetCallback = Future<void> Function(String budgetId);

final class BudgetSelectionScreen extends StatefulWidget {
  const BudgetSelectionScreen({
    required this.services,
    required this.userId,
    required this.budgets,
    required this.onSelect,
    required this.onMembershipChanged,
    required this.onJoined,
    this.activeBudgetId,
    super.key,
  });

  final AppServices services;
  final String userId;
  final List<BudgetSummary> budgets;
  final SelectBudgetCallback onSelect;
  final VoidCallback onMembershipChanged;
  final VoidCallback onJoined;
  final String? activeBudgetId;

  @override
  State<BudgetSelectionScreen> createState() => _BudgetSelectionScreenState();
}

final class _BudgetSelectionScreenState extends State<BudgetSelectionScreen> {
  String? _selectingBudgetId;
  String? _errorMessage;

  Future<void> _create() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateBudgetDialog(
        onCreate:
            ({
              required budgetName,
              required baseCurrency,
              required applyDefaultCategories,
            }) => widget.services.createAdditionalBudget(
              userId: widget.userId,
              budgetName: budgetName,
              baseCurrency: baseCurrency,
              applyDefaultCategories: applyDefaultCategories,
            ),
      ),
    );
    if (created == true && mounted) widget.onMembershipChanged();
  }

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
          if (widget.budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Нет доступных бюджетов. Создайте бюджет или примите приглашение.',
              ),
            ),
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
                    : budget.id == widget.activeBudgetId
                    ? const Icon(Icons.check_circle_outline)
                    : const Icon(Icons.chevron_right),
                onTap: _selectingBudgetId == null
                    ? () => _select(budget.id)
                    : null,
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('create-additional-budget'),
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('Создать бюджет'),
          ),
          const SizedBox(height: 12),
          const Text('Присоединиться по приглашению'),
          const SizedBox(height: 8),
          BudgetInvitePanel(
            services: widget.services,
            budgetId: widget.activeBudgetId ?? '',
            canCreate: false,
            onJoined: widget.onJoined,
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

final class _CreateBudgetDialog extends StatefulWidget {
  const _CreateBudgetDialog({required this.onCreate});

  final Future<Object?> Function({
    required String budgetName,
    required Currency baseCurrency,
    required bool applyDefaultCategories,
  })
  onCreate;

  @override
  State<_CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

final class _CreateBudgetDialogState extends State<_CreateBudgetDialog> {
  final _name = TextEditingController();
  final _currency = TextEditingController(text: 'EUR');
  bool _defaultCategories = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onCreate(
        budgetName: _name.text,
        baseCurrency: Currency(_currency.text),
        applyDefaultCategories: _defaultCategories,
      );
      if (mounted) Navigator.pop(context, true);
    } on OnboardingError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on DomainValidationError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Не удалось создать бюджет. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Новый бюджет'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('new-budget-name'),
            controller: _name,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'Название бюджета'),
          ),
          TextField(
            key: const ValueKey('new-budget-currency'),
            controller: _currency,
            enabled: !_submitting,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Базовая валюта'),
          ),
          CheckboxListTile(
            value: _defaultCategories,
            title: const Text('Стандартные категории'),
            onChanged: _submitting
                ? null
                : (value) => setState(() => _defaultCategories = value ?? true),
          ),
          if (_error != null)
            Text(_error!, key: const ValueKey('new-budget-error')),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context, false),
        child: const Text('Отмена'),
      ),
      FilledButton(
        key: const ValueKey('new-budget-submit'),
        onPressed: _submitting ? null : _submit,
        child: const Text('Создать'),
      ),
    ],
  );
}

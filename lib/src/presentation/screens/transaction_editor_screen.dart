import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/account_error.dart';
import '../../application/errors/transaction_error.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/errors/domain_validation_error.dart';
import '../../domain/models/budget_account.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';

final class TransactionEditorScreen extends StatefulWidget {
  const TransactionEditorScreen({
    required this.services,
    required this.budgetId,
    required this.authorId,
    this.transaction,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final String authorId;
  final BudgetTransactionEntry? transaction;

  @override
  State<TransactionEditorScreen> createState() =>
      _TransactionEditorScreenState();
}

final class _TransactionEditorScreenState extends State<TransactionEditorScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late TransactionType _type;
  late DateTime _occurredAt;
  String? _accountId;
  String? _categoryId;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type = transaction?.type == TransactionType.income
        ? TransactionType.income
        : TransactionType.expense;
    _occurredAt = transaction?.occurredAt ?? DateTime.now();
    _accountId = transaction?.accountId;
    _categoryId = transaction?.categoryId;
    _amountController = TextEditingController(
      text: transaction == null
          ? ''
          : formatMinorUnits(transaction.amount.minorUnits),
    );
    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final accountId = _accountId;
    final categoryId = _categoryId;
    if (accountId == null || categoryId == null) {
      setState(() {
        _error = 'Выберите счет и категорию.';
      });
      return;
    }

    BigInt amountMinor;
    try {
      amountMinor = parseMinorUnitsText(_amountController.text);
    } on FormatException catch (error) {
      setState(() {
        _error = error.message.toString();
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final current = widget.transaction;
      if (current == null) {
        await widget.services.createTransaction(
          budgetId: widget.budgetId,
          authorId: widget.authorId,
          occurredAt: _occurredAt,
          amountMinor: amountMinor,
          type: _type,
          accountId: accountId,
          categoryId: categoryId,
          description: _descriptionController.text,
        );
      } else {
        await widget.services.updateTransaction(
          budgetId: widget.budgetId,
          transactionId: current.id,
          occurredAt: _occurredAt,
          amountMinor: amountMinor,
          type: _type,
          accountId: accountId,
          categoryId: categoryId,
          description: _descriptionController.text,
        );
      }

      if (mounted) Navigator.pop(context);
    } on AccountError catch (error) {
      _showError(error.message);
    } on TransactionError catch (error) {
      _showError(error.message);
    } on DomainValidationError catch (error) {
      _showError(error.message);
    } on Object {
      _showError('Не удалось сохранить операцию.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить операцию' : 'Новая операция'),
      ),
      body: StreamBuilder<List<BudgetAccount>>(
        stream: widget.services.watchBudgetAccounts(
          widget.budgetId,
          includeArchived: false,
        ),
        builder: (context, accountSnapshot) {
          return StreamBuilder<List<BudgetCategory>>(
            stream: widget.services.watchBudgetCategories(
              widget.budgetId,
              includeArchived: false,
            ),
            builder: (context, categorySnapshot) {
              if (accountSnapshot.hasError || categorySnapshot.hasError) {
                return const Center(
                  child: Text('Не удалось загрузить счета или категории.'),
                );
              }
              if (!accountSnapshot.hasData || !categorySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final accounts = accountSnapshot.data!;
              final categories = categorySnapshot.data!
                  .where((category) => _categoryMatches(_type, category))
                  .toList(growable: false);

              if (_accountId != null &&
                  accounts.every((account) => account.id != _accountId)) {
                _accountId = null;
              }
              if (_categoryId != null &&
                  categories.every((category) => category.id != _categoryId)) {
                _categoryId = null;
              }
              if (_accountId == null && accounts.length == 1) {
                _accountId = accounts.single.id;
              }
              if (_categoryId == null && categories.length == 1) {
                _categoryId = categories.single.id;
              }

              return ListView(
                key: const ValueKey('transaction-editor'),
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<TransactionType>(
                    key: const ValueKey('transaction-type'),
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Расход'),
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Доход'),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: _saving
                        ? null
                        : (selection) {
                            setState(() {
                              _type = selection.single;
                              _categoryId = null;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('transaction-amount'),
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('transaction-account'),
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Счет',
                      border: OutlineInputBorder(),
                    ),
                    items: accounts
                        .map(
                          (account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              '${account.name} · ${account.currency.code}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _accountId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('transaction-category'),
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    key: const ValueKey('transaction-date'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Дата и время'),
                    subtitle: Text(_formatDateTime(_occurredAt)),
                    onTap: _saving ? null : _pickDateTime,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('transaction-description'),
                    controller: _descriptionController,
                    enabled: !_saving,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('transaction-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('save-transaction'),
                    onPressed: _saving || accounts.isEmpty || categories.isEmpty
                        ? null
                        : _save,
                    child: Text(_editing ? 'Сохранить' : 'Добавить'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

bool _categoryMatches(
  TransactionType type,
  BudgetCategory category,
) {
  return switch (type) {
    TransactionType.income =>
      category.kind == CategoryKind.income || category.kind == CategoryKind.both,
    TransactionType.expense =>
      category.kind == CategoryKind.expense || category.kind == CategoryKind.both,
    TransactionType.transfer => false,
  };
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

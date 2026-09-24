import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/budget_account.dart';
import '../../domain/models/budget_category.dart';
import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import '../../domain/models/transaction_filter.dart';
import 'transaction_editor_screen.dart';

final class TransactionCrudScreen extends StatefulWidget {
  const TransactionCrudScreen({
    required this.services,
    required this.budgetId,
    required this.userId,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final String userId;

  @override
  State<TransactionCrudScreen> createState() => _TransactionCrudScreenState();
}

final class _TransactionCrudScreenState extends State<TransactionCrudScreen> {
  DateTime? _fromInclusive;
  DateTime? _toExclusive;
  TransactionType? _type;
  String? _categoryId;
  String? _accountId;
  bool _onlyMine = false;

  TransactionFilter get _filter => TransactionFilter(
    budgetId: widget.budgetId,
    fromInclusive: _fromInclusive,
    toExclusive: _toExclusive,
    type: _type,
    categoryId: _categoryId,
    accountId: _accountId,
    authorId: _onlyMine ? widget.userId : null,
  );

  int get _filterCount => [
    _fromInclusive,
    _toExclusive,
    _type,
    _categoryId,
    _accountId,
    _onlyMine ? widget.userId : null,
  ].where((value) => value != null).length;

  Future<void> _openEditor({BudgetTransactionEntry? transaction}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TransactionEditorScreen(
          services: widget.services,
          budgetId: widget.budgetId,
          authorId: widget.userId,
          transaction: transaction,
        ),
      ),
    );
  }

  Future<void> _openFilters(
    List<BudgetAccount> accounts,
    List<BudgetCategory> categories,
  ) async {
    final result = await showModalBottomSheet<_FilterDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TransactionFilterSheet(
        initial: _FilterDraft(
          fromInclusive: _fromInclusive,
          toExclusive: _toExclusive,
          type: _type,
          categoryId: _categoryId,
          accountId: _accountId,
          onlyMine: _onlyMine,
        ),
        accounts: accounts,
        categories: categories,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _fromInclusive = result.fromInclusive;
      _toExclusive = result.toExclusive;
      _type = result.type;
      _categoryId = result.categoryId;
      _accountId = result.accountId;
      _onlyMine = result.onlyMine;
    });
  }

  Future<void> _delete(BudgetTransactionEntry transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить операцию?'),
        content: const Text(
          'Операция будет скрыта из журнала и отчетов. '
          'Удаление выполняется безопасно через soft delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-transaction'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.services.deleteTransaction(
        budgetId: widget.budgetId,
        transactionId: transaction.id,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить операцию.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetAccount>>(
      stream: widget.services.watchBudgetAccounts(
        widget.budgetId,
        includeArchived: true,
      ),
      builder: (context, accountSnapshot) {
        return StreamBuilder<List<BudgetCategory>>(
          stream: widget.services.watchBudgetCategories(
            widget.budgetId,
            includeArchived: true,
          ),
          builder: (context, categorySnapshot) {
            if (accountSnapshot.hasError || categorySnapshot.hasError) {
              return const Center(
                child: Text('Не удалось загрузить справочники операций.'),
              );
            }
            if (!accountSnapshot.hasData || !categorySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final accounts = accountSnapshot.data!;
            final categories = categorySnapshot.data!;
            final accountNames = {
              for (final account in accounts) account.id: account.name,
            };
            final categoryNames = {
              for (final category in categories) category.id: category.name,
            };

            return StreamBuilder<List<BudgetTransactionEntry>>(
              stream: widget.services.watchFilteredTransactions(_filter),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Не удалось загрузить операции.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data!;
                return ListView(
                  key: const ValueKey('transaction-crud'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('add-transaction'),
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить операцию'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('transaction-filters'),
                          onPressed: () => _openFilters(accounts, categories),
                          icon: const Icon(Icons.filter_list),
                          label: Text(
                            _filterCount == 0
                                ? 'Фильтры'
                                : 'Фильтры ($_filterCount)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            _filterCount == 0
                                ? 'Операций пока нет.'
                                : 'По выбранным фильтрам операций нет.',
                          ),
                        ),
                      )
                    else
                      for (final transaction in transactions)
                        Card(
                          child: ListTile(
                            key: ValueKey('transaction-${transaction.id}'),
                            leading: Icon(_typeIcon(transaction.type)),
                            title: Text(
                              '${_amountPrefix(transaction.type)}'
                              '${formatMinorUnits(transaction.amount.minorUnits)} '
                              '${transaction.amount.currency.code}',
                            ),
                            subtitle: Text(
                              _subtitle(
                                transaction,
                                accountNames,
                                categoryNames,
                                widget.userId,
                              ),
                            ),
                            onTap: () => _openEditor(transaction: transaction),
                            trailing: PopupMenuButton<_TransactionAction>(
                              key: ValueKey(
                                'transaction-menu-${transaction.id}',
                              ),
                              onSelected: (action) {
                                switch (action) {
                                  case _TransactionAction.edit:
                                    _openEditor(transaction: transaction);
                                    return;
                                  case _TransactionAction.delete:
                                    _delete(transaction);
                                    return;
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _TransactionAction.edit,
                                  child: Text('Изменить'),
                                ),
                                PopupMenuItem(
                                  value: _TransactionAction.delete,
                                  child: Text('Удалить'),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _TransactionAction { edit, delete }

final class _FilterDraft {
  const _FilterDraft({
    this.fromInclusive,
    this.toExclusive,
    this.type,
    this.categoryId,
    this.accountId,
    this.onlyMine = false,
  });

  final DateTime? fromInclusive;
  final DateTime? toExclusive;
  final TransactionType? type;
  final String? categoryId;
  final String? accountId;
  final bool onlyMine;
}

final class _TransactionFilterSheet extends StatefulWidget {
  const _TransactionFilterSheet({
    required this.initial,
    required this.accounts,
    required this.categories,
  });

  final _FilterDraft initial;
  final List<BudgetAccount> accounts;
  final List<BudgetCategory> categories;

  @override
  State<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

final class _TransactionFilterSheetState
    extends State<_TransactionFilterSheet> {
  late DateTime? _fromInclusive;
  late DateTime? _toExclusive;
  late TransactionType? _type;
  late String? _categoryId;
  late String? _accountId;
  late bool _onlyMine;

  @override
  void initState() {
    super.initState();
    _fromInclusive = widget.initial.fromInclusive;
    _toExclusive = widget.initial.toExclusive;
    _type = widget.initial.type;
    _categoryId = widget.initial.categoryId;
    _accountId = widget.initial.accountId;
    _onlyMine = widget.initial.onlyMine;
  }

  Future<void> _pickFrom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fromInclusive ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _fromInclusive = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _pickTo() async {
    final initial =
        _toExclusive?.subtract(const Duration(days: 1)) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _toExclusive = DateTime(
        date.year,
        date.month,
        date.day,
      ).add(const Duration(days: 1));
    });
  }

  void _reset() {
    Navigator.pop(context, const _FilterDraft());
  }

  void _apply() {
    Navigator.pop(
      context,
      _FilterDraft(
        fromInclusive: _fromInclusive,
        toExclusive: _toExclusive,
        type: _type,
        categoryId: _categoryId,
        accountId: _accountId,
        onlyMine: _onlyMine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            key: const ValueKey('transaction-filter-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Фильтры операций',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TransactionType?>(
                key: const ValueKey('filter-type'),
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Тип',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Все типы')),
                  DropdownMenuItem(
                    value: TransactionType.expense,
                    child: Text('Расход'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.income,
                    child: Text('Доход'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.transfer,
                    child: Text('Перевод'),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const ValueKey('filter-account'),
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Счет',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все счета')),
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const ValueKey('filter-category'),
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Все категории'),
                  ),
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('filter-from'),
                      onPressed: _pickFrom,
                      child: Text(
                        _fromInclusive == null
                            ? 'С даты'
                            : 'С ${_dateOnly(_fromInclusive!)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('filter-to'),
                      onPressed: _pickTo,
                      child: Text(
                        _toExclusive == null
                            ? 'По дату'
                            : 'По ${_dateOnly(_toExclusive!.subtract(const Duration(days: 1)))}',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('filter-only-mine'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Только мои операции'),
                value: _onlyMine,
                onChanged: (value) => setState(() => _onlyMine = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    key: const ValueKey('reset-filters'),
                    onPressed: _reset,
                    child: const Text('Сбросить'),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('apply-filters'),
                    onPressed: _apply,
                    child: const Text('Применить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _typeIcon(TransactionType type) {
  return switch (type) {
    TransactionType.income => Icons.add_circle_outline,
    TransactionType.expense => Icons.remove_circle_outline,
    TransactionType.transfer => Icons.swap_horiz,
  };
}

String _amountPrefix(TransactionType type) {
  return switch (type) {
    TransactionType.income => '+',
    TransactionType.expense => '-',
    TransactionType.transfer => '↔ ',
  };
}

String _subtitle(
  BudgetTransactionEntry transaction,
  Map<String, String> accountNames,
  Map<String, String> categoryNames,
  String currentUserId,
) {
  final source = accountNames[transaction.accountId] ?? transaction.accountId;
  final destinationId = transaction.destinationAccountId;
  final accountText = destinationId == null
      ? source
      : '$source → ${accountNames[destinationId] ?? destinationId}';
  final category = transaction.categoryId == null
      ? 'Перевод'
      : categoryNames[transaction.categoryId!] ?? transaction.categoryId!;
  final author = transaction.authorId == currentUserId
      ? 'Вы'
      : transaction.authorId;

  return [
    _date(transaction.occurredAt),
    accountText,
    category,
    'Автор: $author',
    if (transaction.description != null) transaction.description!,
  ].join(' · ');
}

String _date(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _dateOnly(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/budget_transaction_entry.dart';
import '../../domain/models/domain_types.dart';
import 'transaction_editor_screen.dart';

final class TransactionCrudScreen extends StatelessWidget {
  const TransactionCrudScreen({
    required this.services,
    required this.budgetId,
    required this.userId,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final String userId;

  Future<void> _openEditor(
    BuildContext context, {
    BudgetTransactionEntry? transaction,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TransactionEditorScreen(
          services: services,
          budgetId: budgetId,
          authorId: userId,
          transaction: transaction,
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    BudgetTransactionEntry transaction,
  ) async {
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
    if (confirmed != true || !context.mounted) return;

    try {
      await services.deleteTransaction(
        budgetId: budgetId,
        transactionId: transaction.id,
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить операцию.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetTransactionEntry>>(
      stream: services.watchTransactions(budgetId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Не удалось загрузить операции.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!;
        return ListView(
          key: const ValueKey('transaction-crud'),
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              key: const ValueKey('add-transaction'),
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Добавить операцию'),
            ),
            const SizedBox(height: 16),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Операций пока нет.'),
                ),
              )
            else
              for (final transaction in transactions)
                Card(
                  child: ListTile(
                    key: ValueKey('transaction-${transaction.id}'),
                    leading: Icon(
                      transaction.type == TransactionType.income
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                    title: Text(
                      '${transaction.type == TransactionType.income ? '+' : '-'}'
                      '${formatMinorUnits(transaction.amount.minorUnits)} '
                      '${transaction.amount.currency.code}',
                    ),
                    subtitle: Text(
                      [
                        _date(transaction.occurredAt),
                        if (transaction.description != null)
                          transaction.description!,
                      ].join(' · '),
                    ),
                    onTap: () => _openEditor(
                      context,
                      transaction: transaction,
                    ),
                    trailing: PopupMenuButton<_TransactionAction>(
                      key: ValueKey('transaction-menu-${transaction.id}'),
                      onSelected: (action) {
                        switch (action) {
                          case _TransactionAction.edit:
                            _openEditor(context, transaction: transaction);
                            return;
                          case _TransactionAction.delete:
                            _delete(context, transaction);
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
  }
}

enum _TransactionAction { edit, delete }

String _date(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

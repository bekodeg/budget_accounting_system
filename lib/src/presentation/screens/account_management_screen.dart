import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/account_error.dart';
import '../../application/formatters/minor_units_text.dart';
import '../../domain/models/account_balance.dart';
import '../../domain/models/budget_account.dart';
import '../../domain/value_objects/currency.dart';

final class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({
    required this.services,
    required this.budgetId,
    super.key,
  });

  final AppServices services;
  final String budgetId;

  Future<void> _create(BuildContext context) async {
    final draft = await showDialog<_AccountDraft>(
      context: context,
      builder: (context) => const _AccountEditorDialog(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await services.createAccount(
        budgetId: budgetId,
        name: draft.name,
        currency: draft.currency,
        openingBalanceMinor: draft.openingBalanceMinor,
      );
    } on AccountError catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on FormatException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, 'Не удалось создать счет.');
    }
  }

  Future<void> _edit(
    BuildContext context,
    BudgetAccount account,
  ) async {
    final draft = await showDialog<_AccountDraft>(
      context: context,
      builder: (context) => _AccountEditorDialog(account: account),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await services.updateAccount(
        budgetId: budgetId,
        accountId: account.id,
        name: draft.name,
        currency: draft.currency,
        openingBalanceMinor: draft.openingBalanceMinor,
      );
    } on AccountError catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on FormatException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, 'Не удалось изменить счет.');
    }
  }

  Future<void> _archive(
    BuildContext context,
    BudgetAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Архивировать счет?'),
        content: Text(
          '«${account.name}» останется в истории, но не будет '
          'предлагаться для новых операций.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('confirm-archive-account'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Архивировать'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await services.archiveAccount(
        budgetId: budgetId,
        accountId: account.id,
      );
    } on AccountError catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, 'Не удалось архивировать счет.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetAccount>>(
      stream: services.watchBudgetAccounts(
        budgetId,
        includeArchived: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Не удалось загрузить счета.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snapshot.data!;
        final active = accounts
            .where((account) => !account.isArchived)
            .toList(growable: false);
        final archived = accounts
            .where((account) => account.isArchived)
            .toList(growable: false);

        return ListView(
          key: const ValueKey('account-management'),
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              key: const ValueKey('add-account'),
              onPressed: () => _create(context),
              icon: const Icon(Icons.add_card),
              label: const Text('Добавить счет'),
            ),
            const SizedBox(height: 16),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Активных счетов пока нет.')),
              )
            else
              for (final account in active)
                _AccountTile(
                  account: account,
                  balance: services.getAccountBalance(
                    budgetId: budgetId,
                    accountId: account.id,
                  ),
                  onEdit: () => _edit(context, account),
                  onArchive: () => _archive(context, account),
                ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Архив', style: Theme.of(context).textTheme.titleMedium),
              for (final account in archived)
                ListTile(
                  key: ValueKey('archived-account-${account.id}'),
                  enabled: false,
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(account.name),
                  subtitle: Text(
                    '${formatMinorUnits(account.openingBalanceMinor)} '
                    '${account.currency.code}',
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

final class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.onEdit,
    required this.onArchive,
  });

  final BudgetAccount account;
  final Future<AccountBalance> balance;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: ValueKey('account-${account.id}'),
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(account.name),
        subtitle: FutureBuilder<AccountBalance>(
          future: balance,
          builder: (context, snapshot) {
            final value = snapshot.data;
            if (value == null) {
              return Text(
                'Начальный: ${formatMinorUnits(account.openingBalanceMinor)} '
                '${account.currency.code}',
              );
            }
            return Text(
              'Остаток: ${formatMinorUnits(value.minorUnits)} '
              '${value.currency.code}',
              key: ValueKey('account-balance-${account.id}'),
            );
          },
        ),
        trailing: PopupMenuButton<_AccountAction>(
          key: ValueKey('account-menu-${account.id}'),
          onSelected: (action) {
            switch (action) {
              case _AccountAction.edit:
                onEdit();
                return;
              case _AccountAction.archive:
                onArchive();
                return;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _AccountAction.edit,
              child: Text('Изменить'),
            ),
            PopupMenuItem(
              value: _AccountAction.archive,
              child: Text('Архивировать'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AccountAction { edit, archive }

final class _AccountDraft {
  const _AccountDraft({
    required this.name,
    required this.currency,
    required this.openingBalanceMinor,
  });

  final String name;
  final Currency currency;
  final BigInt openingBalanceMinor;
}

final class _AccountEditorDialog extends StatefulWidget {
  const _AccountEditorDialog({this.account});

  final BudgetAccount? account;

  @override
  State<_AccountEditorDialog> createState() => _AccountEditorDialogState();
}

final class _AccountEditorDialogState extends State<_AccountEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;
  late final TextEditingController _openingBalanceController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _currencyController = TextEditingController(
      text: account?.currency.code ?? 'EUR',
    );
    _openingBalanceController = TextEditingController(
      text: formatMinorUnits(account?.openingBalanceMinor ?? BigInt.zero),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  void _usePreset(String name) {
    _nameController.text = name;
  }

  void _submit() {
    try {
      final draft = _AccountDraft(
        name: _nameController.text,
        currency: Currency(_currencyController.text),
        openingBalanceMinor: parseMinorUnitsText(
          _openingBalanceController.text,
        ),
      );
      Navigator.pop(context, draft);
    } on Object catch (error) {
      setState(() {
        _error = error is FormatException
            ? error.message
            : 'Проверьте валюту и начальный остаток.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'Новый счет' : 'Изменить счет'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final preset in ['Наличные', 'Карта', 'Банк'])
                  ActionChip(
                    label: Text(preset),
                    onPressed: () => _usePreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account-name-input'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account-currency-input'),
              controller: _currencyController,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Валюта',
                hintText: 'EUR',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account-opening-balance-input'),
              controller: _openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Начальный остаток',
                helperText: 'Например: 1250.50 или -100.00',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const ValueKey('account-editor-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('save-account'),
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

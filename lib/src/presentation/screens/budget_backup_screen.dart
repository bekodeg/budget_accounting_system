import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/errors/budget_backup_error.dart';
import '../../domain/models/budget_backup.dart';

final class BudgetBackupScreen extends StatefulWidget {
  const BudgetBackupScreen({
    required this.services,
    required this.budgetId,
    super.key,
  });

  final AppServices services;
  final String budgetId;

  @override
  State<BudgetBackupScreen> createState() => _BudgetBackupScreenState();
}

final class _BudgetBackupScreenState extends State<BudgetBackupScreen> {
  final _exportPassword = TextEditingController();
  final _importPassword = TextEditingController();
  String? _pickedPayload;
  BudgetBackupPreview? _preview;
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _exportPassword.dispose();
    _importPassword.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final export = widget.services.exportBudgetBackup;
    if (export == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await export(
        budgetId: widget.budgetId,
        password: _exportPassword.text,
      );
      _showMessage('Зашифрованный backup подготовлен для сохранения.', false);
    } on BudgetBackupError catch (error) {
      _showMessage(error.message, true);
    } on Object {
      _showMessage('Не удалось создать backup.', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final pick = widget.services.pickBudgetBackup;
    if (pick == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _preview = null;
    });
    try {
      final payload = await pick();
      if (!mounted) return;
      setState(() => _pickedPayload = payload);
      if (payload != null) {
        _showMessage('Файл выбран. Введите пароль для preview.', false);
      }
    } on Object {
      _showMessage('Не удалось прочитать файл backup.', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPreview() async {
    final preview = widget.services.previewBudgetBackup;
    final payload = _pickedPayload;
    if (preview == null || payload == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _preview = null;
    });
    try {
      final result = await preview(
        payload: payload,
        password: _importPassword.text,
      );
      if (!mounted) return;
      setState(() => _preview = result);
    } on BudgetBackupError catch (error) {
      _showMessage(error.message, true);
    } on Object {
      _showMessage('Не удалось проверить backup.', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final restore = widget.services.restoreBudgetBackup;
    final payload = _pickedPayload;
    if (restore == null || payload == null || _preview == null || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('backup-restore-confirm'),
        title: const Text('Восстановить бюджет?'),
        content: const Text(
          'Данные будут записаны только после повторной проверки backup. '
          'Если бюджет с таким ID уже существует, будет создан отдельный бюджет.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('backup-restore-confirm-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await restore(
        payload: payload,
        password: _importPassword.text,
      );
      _showMessage(
        result.restoredAsNewBudget
            ? 'Backup восстановлен как новый бюджет: ${result.budgetId}'
            : 'Бюджет восстановлен: ${result.budgetId}',
        false,
      );
      if (mounted) {
        setState(() {
          _pickedPayload = null;
          _preview = null;
          _importPassword.clear();
        });
      }
    } on BudgetBackupError catch (error) {
      _showMessage(error.message, true);
    } on Object {
      _showMessage('Не удалось восстановить backup.', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, bool error) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.services.exportBudgetBackup != null &&
        widget.services.pickBudgetBackup != null &&
        widget.services.previewBudgetBackup != null &&
        widget.services.restoreBudgetBackup != null;

    if (!enabled) {
      return const Center(child: Text('Backup недоступен в этой конфигурации.'));
    }

    return ListView(
      key: const ValueKey('budget-backup-screen'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Экспорт', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('backup-export-password'),
          controller: _exportPassword,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Пароль backup (минимум 8 символов)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('backup-export'),
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Создать зашифрованный backup'),
        ),
        const Divider(height: 32),
        Text('Восстановление', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('backup-pick'),
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(
            _pickedPayload == null ? 'Выбрать backup' : 'Backup выбран',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('backup-import-password'),
          controller: _importPassword,
          obscureText: true,
          enabled: _pickedPayload != null && !_busy,
          decoration: const InputDecoration(
            labelText: 'Пароль backup',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const ValueKey('backup-preview'),
          onPressed: _pickedPayload == null || _busy ? null : _loadPreview,
          child: const Text('Проверить и показать состав'),
        ),
        if (_preview case final preview?) ...[
          const SizedBox(height: 12),
          Card(
            key: const ValueKey('backup-preview-card'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.budgetName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Валюта: ${preview.baseCurrency} · '
                    'участники: ${preview.memberCount} · '
                    'счета: ${preview.accountCount} · '
                    'категории: ${preview.categoryCount}',
                  ),
                  Text(
                    'Операции: ${preview.transactionCount} · '
                    'планы: ${preview.planCount} · '
                    'чеки: ${preview.receiptCount}',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey('backup-restore'),
                    onPressed: _busy ? null : _restore,
                    child: const Text('Восстановить'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            key: const ValueKey('backup-message'),
            style: TextStyle(
              color: _error ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ],
    );
  }
}

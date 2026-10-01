import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../application/app_services.dart';
import '../../application/errors/invite_error.dart';
import '../../domain/models/budget_invite.dart';
import '../../domain/models/domain_types.dart';

final class BudgetInvitePanel extends StatelessWidget {
  const BudgetInvitePanel({
    required this.services,
    required this.budgetId,
    required this.canCreate,
    super.key,
  });

  final AppServices services;
  final String budgetId;
  final bool canCreate;

  Future<void> _create(BuildContext context) async {
    final role = await showDialog<MemberRole>(
      context: context,
      builder: (context) => const _InviteRoleDialog(),
    );
    if (role == null || !context.mounted) return;

    try {
      final preview = await services.createBudgetInvite(
        budgetId: budgetId,
        role: role,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _CreatedInviteDialog(
          preview: preview,
          onShareFile: () => services.shareBudgetInviteFile(preview),
        ),
      );
    } on Object {
      if (context.mounted) {
        _message(context, 'Не удалось создать приглашение.');
      }
    }
  }

  Future<void> _importFile(BuildContext context) async {
    try {
      final raw = await services.pickBudgetInviteFile();
      if (raw == null || !context.mounted) return;
      await _inspectAndConfirm(context, raw);
    } on Object {
      if (context.mounted) {
        _message(context, 'Не удалось прочитать файл приглашения.');
      }
    }
  }

  Future<void> _scanQr(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const InviteQrScannerScreen()),
    );
    if (raw == null || !context.mounted) return;
    await _inspectAndConfirm(context, raw);
  }

  Future<void> _inspectAndConfirm(BuildContext context, String raw) async {
    try {
      final preview = await services.inspectBudgetInvite(raw);
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _AcceptInviteDialog(preview: preview),
      );
      if (confirmed != true || !context.mounted) return;

      await services.acceptBudgetInvite(raw);
      if (context.mounted) {
        _message(
          context,
          'Вы присоединились к бюджету «${preview.invite.budgetName}».',
        );
      }
    } on InviteError catch (error) {
      if (context.mounted) _message(context, error.message);
    } on Object {
      if (context.mounted) {
        _message(context, 'Не удалось принять приглашение.');
      }
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canCreate)
          FilledButton.icon(
            key: const ValueKey('create-budget-invite'),
            onPressed: () => _create(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Пригласить'),
          ),
        OutlinedButton.icon(
          key: const ValueKey('scan-budget-invite'),
          onPressed: () => _scanQr(context),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Сканировать QR'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('import-budget-invite-file'),
          onPressed: () => _importFile(context),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Открыть файл'),
        ),
      ],
    );
  }
}

final class _InviteRoleDialog extends StatelessWidget {
  const _InviteRoleDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Роль приглашения'),
      content: const Text(
        'EDITOR может изменять бюджет. VIEWER имеет доступ только на чтение '
        'и экспорт.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, MemberRole.viewer),
          child: const Text('VIEWER'),
        ),
        FilledButton(
          key: const ValueKey('invite-role-editor'),
          onPressed: () => Navigator.pop(context, MemberRole.editor),
          child: const Text('EDITOR'),
        ),
      ],
    );
  }
}

final class _CreatedInviteDialog extends StatelessWidget {
  const _CreatedInviteDialog({
    required this.preview,
    required this.onShareFile,
  });

  final BudgetInvitePreview preview;
  final Future<void> Function() onShareFile;

  @override
  Widget build(BuildContext context) {
    final invite = preview.invite;
    return AlertDialog(
      title: const Text('Приглашение создано'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 240,
              child: QrImageView(
                key: const ValueKey('budget-invite-qr'),
                data: preview.rawPayload,
              ),
            ),
            const SizedBox(height: 12),
            Text(invite.budgetName),
            Text('Роль: ${_roleLabel(invite.role)}'),
            Text('Действует до: ${_dateTime(invite.expiresAt)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('share-budget-invite-file'),
          onPressed: () async {
            await onShareFile();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Поделиться файлом'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

final class _AcceptInviteDialog extends StatelessWidget {
  const _AcceptInviteDialog({required this.preview});

  final BudgetInvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final invite = preview.invite;
    return AlertDialog(
      title: const Text('Присоединиться к бюджету?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Бюджет: ${invite.budgetName}'),
          Text('Валюта: ${invite.baseCurrency}'),
          Text('Роль: ${_roleLabel(invite.role)}'),
          Text('Владелец: ${invite.ownerName}'),
          Text('Действует до: ${_dateTime(invite.expiresAt)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('accept-budget-invite'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Присоединиться'),
        ),
      ],
    );
  }
}

final class InviteQrScannerScreen extends StatefulWidget {
  const InviteQrScannerScreen({super.key});

  @override
  State<InviteQrScannerScreen> createState() => _InviteQrScannerScreenState();
}

final class _InviteQrScannerScreenState extends State<InviteQrScannerScreen> {
  bool _handled = false;

  void _detect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || !raw.startsWith('budgetinvite:')) return;

    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканировать приглашение')),
      body: MobileScanner(
        key: const ValueKey('budget-invite-scanner'),
        onDetect: _detect,
      ),
    );
  }
}

String _roleLabel(MemberRole role) => switch (role) {
  MemberRole.editor => 'EDITOR',
  MemberRole.viewer => 'VIEWER',
  MemberRole.owner => 'OWNER',
};

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

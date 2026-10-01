import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../domain/models/diagnostic_package.dart';

final class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({required this.services, super.key});

  final AppServices services;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

final class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _exporting = false;
  String? _message;

  Future<void> _export() async {
    final export = widget.services.exportDiagnostics;
    if (export == null || _exporting) return;
    setState(() {
      _exporting = true;
      _message = null;
    });
    try {
      await export();
      if (!mounted) return;
      setState(() => _message = 'Diagnostic package подготовлен.');
    } on Object {
      if (!mounted) return;
      setState(() => _message = 'Не удалось экспортировать диагностику.');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.services.previewDiagnostics;
    if (preview == null) {
      return const Center(child: Text('Диагностика недоступна.'));
    }

    return FutureBuilder<DiagnosticPackagePreview>(
      future: preview(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось подготовить preview диагностики.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          key: const ValueKey('diagnostics-preview'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Что будет экспортировано',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Пакет содержит только технические версии, агрегированные '
              'счетчики и безопасные коды ошибок. Суммы, комментарии, QR, '
              'имена, идентификаторы и ключи не экспортируются.',
            ),
            const SizedBox(height: 16),
            _row('Версия приложения', data.appVersion),
            _row('Schema', data.schemaVersion.toString()),
            _row('Snapshot protocol', data.snapshotProtocolVersion.toString()),
            _row('Платформа', data.platform),
            _row('Бюджетов (count)', data.budgetCount.toString()),
            _row('Sync operations (count)', data.syncOperationCount.toString()),
            _row(
              'Failed receipt OCR (count)',
              data.failedReceiptCount.toString(),
            ),
            _row('Последних safe errors', data.recentErrorCount.toString()),
            const SizedBox(height: 12),
            Text('Файлы: ${data.archiveEntries.join(', ')}'),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('export-diagnostics'),
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Экспортировать ZIP'),
            ),
            if (_exporting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, key: const ValueKey('diagnostics-message')),
            ],
          ],
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value),
    );
  }
}

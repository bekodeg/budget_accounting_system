import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_build_info.dart';

typedef StartupIssueReporter =
    Future<StartupIssueReportResult> Function(String diagnosticCode);

final class StartupIssueReportResult {
  const StartupIssueReportResult({
    required this.opened,
    required this.copiedToClipboard,
    required this.issueUrl,
  });

  final bool opened;
  final bool copiedToClipboard;
  final String issueUrl;
}

Future<StartupIssueReportResult> reportStartupIssue(
  String diagnosticCode,
) async {
  final issueUrl = buildStartupIssueUrl(diagnosticCode);
  final uri = Uri.parse(issueUrl);
  final copied = await copyIssueUrlToClipboard(issueUrl);

  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } on Object {
    opened = false;
  }

  return StartupIssueReportResult(
    opened: opened,
    copiedToClipboard: copied,
    issueUrl: issueUrl,
  );
}

String buildStartupIssueUrl(
  String diagnosticCode, {
  AppBuildInfo buildInfo = currentBuildInfo,
  DateTime? occurredAt,
}) {
  final safeCode = _singleLine(diagnosticCode, maxLength: 160);
  final platform = _singleLine(Platform.operatingSystem, maxLength: 40);
  final osVersion = _singleLine(
    Platform.operatingSystemVersion,
    maxLength: 240,
  );
  final dartVersion = _singleLine(Platform.version, maxLength: 160);
  final timestamp = (occurredAt ?? DateTime.now().toUtc()).toIso8601String();

  final body =
      '''
## Автоматическая диагностика

- Startup code: `$safeCode`
- App version: `${buildInfo.version}`
- Build channel: `${buildInfo.channel}`
- Build commit: `${buildInfo.commit}`
- Platform: `$platform`
- OS: `$osVersion`
- Dart: `$dartVersion`
- UTC time: `$timestamp`

## Что произошло

Опишите, что было на экране перед ошибкой.

## Шаги воспроизведения

1. Запустить приложение.
2.
3.

## Ожидаемое поведение

Приложение успешно запускается.

## Фактическое поведение

Startup bootstrap завершился ошибкой `$safeCode`.

> Автоматический отчет не содержит ключей шифрования, содержимого БД,
> финансовых данных или текста исключения.
''';

  return Uri.https(
    'github.com',
    '/bekodeg/budget_accounting_system/issues/new',
    <String, String>{
      'title': '[Bug][Startup] $safeCode',
      'body': body,
      'labels': 'bug',
    },
  ).toString();
}

Future<bool> copyIssueUrlToClipboard(String issueUrl) async {
  try {
    await Clipboard.setData(ClipboardData(text: issueUrl));
    final readback = await Clipboard.getData(Clipboard.kTextPlain);
    return readback?.text == issueUrl;
  } on Object {
    return false;
  }
}

String _singleLine(String value, {required int maxLength}) {
  final normalized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  if (normalized.isEmpty) return 'unknown';
  return normalized.length <= maxLength
      ? normalized
      : normalized.substring(0, maxLength);
}

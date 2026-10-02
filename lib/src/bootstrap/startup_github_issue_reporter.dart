import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

typedef StartupIssueReporter = Future<bool> Function(String diagnosticCode);

Future<bool> reportStartupIssue(String diagnosticCode) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final safeCode = _singleLine(diagnosticCode, maxLength: 160);
  final platform = _singleLine(Platform.operatingSystem, maxLength: 40);
  final osVersion = _singleLine(
    Platform.operatingSystemVersion,
    maxLength: 240,
  );
  final dartVersion = _singleLine(Platform.version, maxLength: 160);
  final appVersion = _singleLine(
    '${packageInfo.version}+${packageInfo.buildNumber}',
    maxLength: 80,
  );
  final occurredAt = DateTime.now().toUtc().toIso8601String();

  final body =
      '''
## Автоматическая диагностика

- Startup code: `$safeCode`
- App version: `$appVersion`
- Platform: `$platform`
- OS: `$osVersion`
- Dart: `$dartVersion`
- UTC time: `$occurredAt`

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

  final uri = Uri.https(
    'github.com',
    '/bekodeg/budget_accounting_system/issues/new',
    <String, String>{
      'title': '[Bug][Startup] $safeCode',
      'body': body,
      'labels': 'bug',
    },
  );

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _singleLine(String value, {required int maxLength}) {
  final normalized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  if (normalized.isEmpty) return 'unknown';
  return normalized.length <= maxLength
      ? normalized
      : normalized.substring(0, maxLength);
}

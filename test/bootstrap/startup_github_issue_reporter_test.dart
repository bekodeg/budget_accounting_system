import 'package:budget_accounting_system/src/bootstrap/app_build_info.dart';
import 'package:budget_accounting_system/src/bootstrap/startup_github_issue_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('adds safe source location for path-provider startup failures', () {
    const buildInfo = AppBuildInfo(
      version: '0.1.0+2',
      channel: 'stage',
      commit: '08328d9e6dbc',
    );
    final issueUrl = buildStartupIssueUrl(
      'path-resolve:platformexception:channel-error',
      buildInfo: buildInfo,
      occurredAt: DateTime.utc(2026, 10, 5, 9, 55),
    );
    final body = Uri.parse(issueUrl).queryParameters['body'] ?? '';

    expect(body, contains('Class: `DatabaseEncryptionBootstrap`'));
    expect(body, contains('Function: `_defaultDatabasePathResolver`'));
    expect(body, contains('Operation: `getApplicationDocumentsDirectory`'));
    expect(body, contains('Dependency: `path_provider / PathProviderPlugin`'));
  });

  test('builds issue URL from compile-time-safe build info', () {
    const buildInfo = AppBuildInfo(
      version: '0.1.0+42',
      channel: 'stage',
      commit: '0123456789abcdef',
    );
    final issueUrl = buildStartupIssueUrl(
      'sqlite-native-load:dynamiclibraryloaderror',
      buildInfo: buildInfo,
      occurredAt: DateTime.utc(2026, 10, 4, 12, 30),
    );
    final uri = Uri.parse(issueUrl);
    final body = uri.queryParameters['body'] ?? '';

    expect(uri.host, 'github.com');
    expect(body, contains('App version: `0.1.0+42`'));
    expect(body, contains('Build channel: `stage`'));
    expect(body, contains('Build commit: `0123456789abcdef`'));
    expect(
      body,
      contains('Startup code: `sqlite-native-load:dynamiclibraryloaderror`'),
    );
  });

  testWidgets('copies and verifies the exact issue URL', (tester) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>;
        clipboardText = args['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': clipboardText};
      }
      return null;
    });

    const issueUrl =
        'https://github.com/bekodeg/budget_accounting_system/issues/new?title=bug';

    expect(await copyIssueUrlToClipboard(issueUrl), isTrue);
    expect(clipboardText, issueUrl);
  });

  testWidgets('does not claim success when clipboard readback differs', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{
          'text':
              'sha256:4541440fda59fcb60414b427dff8caf6d75e31f30d01b38be76e41bcbf1cea69',
        };
      }
      return null;
    });

    const issueUrl =
        'https://github.com/bekodeg/budget_accounting_system/issues/new';

    expect(await copyIssueUrlToClipboard(issueUrl), isFalse);
  });
}

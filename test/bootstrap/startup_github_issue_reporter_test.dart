import 'package:budget_accounting_system/src/bootstrap/startup_github_issue_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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

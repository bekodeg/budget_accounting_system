import 'package:budget_accounting_system/src/bootstrap/runtime_bootstrap_app.dart';
import 'package:budget_accounting_system/src/bootstrap/startup_diagnostic_exception.dart';
import 'package:budget_accounting_system/src/bootstrap/startup_github_issue_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupReporterHarness());
}

final class _StartupReporterHarness extends StatefulWidget {
  const _StartupReporterHarness();

  @override
  State<_StartupReporterHarness> createState() =>
      _StartupReporterHarnessState();
}

final class _StartupReporterHarnessState
    extends State<_StartupReporterHarness> {
  StartupIssueReportResult? _lastReport;
  bool? _clipboardMatches;

  Future<StartupIssueReportResult> _report(String diagnosticCode) async {
    final result = await reportStartupIssue(diagnosticCode);
    if (mounted) {
      setState(() {
        _lastReport = result;
        _clipboardMatches = null;
      });
    }
    return result;
  }

  Future<void> _checkClipboard() async {
    final expected = _lastReport?.issueUrl;
    String? actual;
    try {
      actual = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on Object {
      // A denied clipboard read is reported as a failed device check.
    }
    if (mounted) {
      setState(
        () => _clipboardMatches = expected != null && actual == expected,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _lastReport;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          RuntimeBootstrapApp(
            loadRuntime: () async => throw const StartupDiagnosticException(
              phase: 'path-resolve',
              causeType: 'platformexception',
              platformCode: 'channel-error',
            ),
            reportIssue: _report,
          ),
          Positioned(
            top: 40,
            right: 8,
            child: Material(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Тест ошибки запуска'),
                    TextButton(
                      onPressed: report == null ? null : _checkClipboard,
                      child: const Text('Проверить буфер'),
                    ),
                    if (report != null)
                      Text(
                        'Открытие: ${report.opened}; '
                        'копия: ${report.copiedToClipboard}',
                      ),
                    if (_clipboardMatches != null)
                      Text('Точное совпадение: $_clipboardMatches'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

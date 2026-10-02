import 'package:flutter/material.dart';

import '../app.dart';
import '../application/app_services.dart';
import 'database_encryption_bootstrap.dart';
import 'startup_diagnostic_exception.dart';
import 'startup_github_issue_reporter.dart';

typedef RuntimeLoader = Future<AppRuntime> Function();

final class AppRuntime {
  const AppRuntime({required this.services, this.onDispose});

  final AppServices services;
  final Future<void> Function()? onDispose;
}

final class RuntimeBootstrapApp extends StatefulWidget {
  const RuntimeBootstrapApp({
    required this.loadRuntime,
    this.reportIssue,
    super.key,
  });

  final RuntimeLoader loadRuntime;
  final StartupIssueReporter? reportIssue;

  @override
  State<RuntimeBootstrapApp> createState() => _RuntimeBootstrapAppState();
}

final class _RuntimeBootstrapAppState extends State<RuntimeBootstrapApp> {
  late Future<AppRuntime> _startup;

  @override
  void initState() {
    super.initState();
    _startup = widget.loadRuntime();
  }

  void _retry() {
    setState(() {
      _startup = widget.loadRuntime();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Accounting',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: FutureBuilder<AppRuntime>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  key: ValueKey('runtime-bootstrap-progress'),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return _StartupFailure(
              error: snapshot.error,
              onRetry: _retry,
              onReportIssue: widget.reportIssue ?? reportStartupIssue,
            );
          }

          final runtime = snapshot.requireData;
          return BudgetAccountingApp(
            services: runtime.services,
            onDispose: runtime.onDispose,
          );
        },
      ),
    );
  }
}

final class _StartupFailure extends StatelessWidget {
  const _StartupFailure({
    required this.error,
    required this.onRetry,
    required this.onReportIssue,
  });

  final Object? error;
  final VoidCallback onRetry;
  final StartupIssueReporter onReportIssue;

  @override
  Widget build(BuildContext context) {
    final isMissingKey = error is DatabaseKeyMissingException;
    final diagnosticCode = _diagnosticCode(error);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    isMissingKey
                        ? 'Не удалось открыть локальные данные'
                        : 'Не удалось запустить приложение',
                    key: const ValueKey('runtime-bootstrap-error'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isMissingKey
                        ? 'Ключ локальной зашифрованной базы недоступен. '
                              'Если данные важны, не удаляйте приложение и '
                              'восстановите ключ или backup.'
                        : 'Проверьте доступ к локальному хранилищу и '
                              'попробуйте снова.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'Код ошибки: $diagnosticCode',
                    key: const ValueKey('runtime-bootstrap-error-code'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('runtime-bootstrap-retry'),
                    onPressed: onRetry,
                    child: const Text('Повторить'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('runtime-bootstrap-report-issue'),
                    onPressed: () async {
                      var opened = false;
                      try {
                        opened = await onReportIssue(diagnosticCode);
                      } on Object {
                        opened = false;
                      }
                      if (!context.mounted || opened) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Не удалось открыть GitHub. '
                            'Скопируйте код ошибки и создайте issue вручную.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Сообщить об ошибке'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _diagnosticCode(Object? error) {
  if (error is DatabaseKeyMissingException) {
    return 'database-key-missing';
  }
  if (error is StartupDiagnosticException) {
    return error.diagnosticCode;
  }
  if (error == null) {
    return 'runtime:unknown';
  }
  return StartupDiagnosticException.fromError(
    phase: 'runtime',
    error: error,
  ).diagnosticCode;
}

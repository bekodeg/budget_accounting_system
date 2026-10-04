import 'dart:async';

import 'package:budget_accounting_system/src/bootstrap/app_build_info.dart';
import 'package:budget_accounting_system/src/bootstrap/database_encryption_bootstrap.dart';
import 'package:budget_accounting_system/src/bootstrap/runtime_bootstrap_app.dart';
import 'package:budget_accounting_system/src/bootstrap/startup_diagnostic_exception.dart';
import 'package:budget_accounting_system/src/bootstrap/startup_github_issue_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('renders a Flutter progress frame before runtime is ready', (
    tester,
  ) async {
    final completer = Completer<AppRuntime>();

    await tester.pumpWidget(
      RuntimeBootstrapApp(loadRuntime: () => completer.future),
    );

    expect(
      find.byKey(const ValueKey('runtime-bootstrap-progress')),
      findsOneWidget,
    );
  });

  testWidgets('shows retry UI and build identity when runtime bootstrap fails', (
    tester,
  ) async {
    var attempts = 0;

    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
    );

    await tester.pumpWidget(
      RuntimeBootstrapApp(
        buildInfo: const AppBuildInfo(
          version: '0.1.0+42',
          channel: 'stage',
          commit: '0123456789abcdef',
        ),
        loadRuntime: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('startup failed');
          }
          return AppRuntime(services: services);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('runtime-bootstrap-error')),
      findsOneWidget,
    );
    expect(find.text('Не удалось запустить приложение'), findsOneWidget);
    expect(find.text('Код ошибки: runtime:stateerror'), findsOneWidget);
    expect(find.text('Версия: 0.1.0+42'), findsOneWidget);
    expect(find.text('Сборка: stage · 0123456789ab'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('runtime-bootstrap-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Первый бюджет'), findsOneWidget);
  });

  testWidgets('explains missing encrypted database key', (tester) async {
    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          throw const DatabaseKeyMissingException();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть локальные данные'), findsOneWidget);
    expect(find.textContaining('не удаляйте приложение'), findsOneWidget);
    expect(find.text('Код ошибки: database-key-missing'), findsOneWidget);
  });

  testWidgets('shows safe startup phase and platform error code', (
    tester,
  ) async {
    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          throw const StartupDiagnosticException(
            phase: 'secure-key-read',
            causeType: 'platformexception',
            platformCode: 'keystore-unavailable',
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Код ошибки: secure-key-read:platformexception:keystore-unavailable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports the startup diagnostic code through GitHub action', (
    tester,
  ) async {
    String? reportedCode;

    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          throw const StartupDiagnosticException(
            phase: 'secure-key-read',
            causeType: 'platformexception',
            platformCode: 'keystore-unavailable',
          );
        },
        reportIssue: (code) async {
          reportedCode = code;
          return const StartupIssueReportResult(
            opened: true,
            copiedToClipboard: true,
            issueUrl: 'https://github.com/example',
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('runtime-bootstrap-report-issue')),
    );
    await tester.pump();

    expect(
      reportedCode,
      'secure-key-read:platformexception:keystore-unavailable',
    );
  });

  testWidgets('shows fallback message when GitHub cannot be opened', (
    tester,
  ) async {
    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          throw StateError('startup failed');
        },
        reportIssue: (_) async => const StartupIssueReportResult(
          opened: false,
          copiedToClipboard: true,
          issueUrl: 'https://github.com/example',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('runtime-bootstrap-report-issue')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Не удалось открыть GitHub'), findsOneWidget);
  });

  testWidgets('shows selectable issue URL when clipboard is unverified', (
    tester,
  ) async {
    const issueUrl =
        'https://github.com/bekodeg/budget_accounting_system/issues/new';

    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async {
          throw StateError('startup failed');
        },
        reportIssue: (_) async => const StartupIssueReportResult(
          opened: false,
          copiedToClipboard: false,
          issueUrl: issueUrl,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('runtime-bootstrap-report-issue')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть GitHub'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-bootstrap-issue-url')),
      findsOneWidget,
    );
    expect(find.text(issueUrl), findsOneWidget);
  });

  testWidgets('shows selectable URL even if reporter throws', (tester) async {
    await tester.pumpWidget(
      RuntimeBootstrapApp(
        buildInfo: const AppBuildInfo(
          version: '0.1.0+42',
          channel: 'stage',
          commit: '0123456789abcdef',
        ),
        loadRuntime: () async {
          throw StateError('startup failed');
        },
        reportIssue: (_) async {
          throw StateError('reporter failed');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('runtime-bootstrap-report-issue')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть GitHub'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('runtime-bootstrap-issue-url')),
      findsOneWidget,
    );
    expect(find.textContaining('github.com'), findsWidgets);
  });

  testWidgets('continues to normal app when runtime loads', (tester) async {
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(),
    );

    await tester.pumpWidget(
      RuntimeBootstrapApp(
        loadRuntime: () async => AppRuntime(services: services),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Первый бюджет'), findsOneWidget);
  });
}

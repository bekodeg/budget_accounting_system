import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/application/ports/diagnostic_log_store.dart';
import 'src/bootstrap/app_composition_root.dart';
import 'src/bootstrap/database_encryption_bootstrap.dart';
import 'src/data/database/app_database.dart';
import 'src/data/security/flutter_secure_database_key_store.dart';
import 'src/data/services/random_secure_token_generator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupHost());
}

final class _StartupHost extends StatefulWidget {
  const _StartupHost();

  @override
  State<_StartupHost> createState() => _StartupHostState();
}

final class _StartupHostState extends State<_StartupHost> {
  late Future<AppCompositionRoot> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _createCompositionRoot();
  }

  void _retry() {
    setState(() {
      _startup = _createCompositionRoot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Accounting',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: FutureBuilder<AppCompositionRoot>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _StartupFailure(
              error: snapshot.error,
              onRetry: _retry,
            );
          }

          final compositionRoot = snapshot.requireData;
          _installSafeErrorCapture(
            compositionRoot.services.diagnosticLogStore,
          );
          return BudgetAccountingApp(
            services: compositionRoot.services,
            onDispose: compositionRoot.close,
          );
        },
      ),
    );
  }
}

Future<AppCompositionRoot> _createCompositionRoot() async {
  final encryption = await DatabaseEncryptionBootstrap(
    keyStore: FlutterSecureDatabaseKeyStore(),
    tokenGenerator: RandomSecureTokenGenerator(),
  ).prepare();
  final database = AppDatabase.encrypted(
    key: encryption.key,
    databasePath: encryption.databasePath,
  );
  return AppCompositionRoot.defaults(database: database);
}

final class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isMissingKey = error is DatabaseKeyMissingException;

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
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('startup-bootstrap-retry'),
                    onPressed: onRetry,
                    child: const Text('Повторить'),
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

void _installSafeErrorCapture(DiagnosticLogStore? logStore) {
  if (logStore == null) return;

  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      logStore.append(
        category: _errorCategory(details.stack),
        code: details.exception.runtimeType.toString(),
      ),
    );
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      logStore.append(
        category: _errorCategory(stack),
        code: error.runtimeType.toString(),
      ),
    );
    return previousPlatformHandler?.call(error, stack) ?? false;
  };
}

String _errorCategory(StackTrace? stack) {
  final value = stack?.toString().toLowerCase() ?? '';
  if (value.contains('sync_') || value.contains('lan_')) return 'sync';
  if (value.contains('drift') || value.contains('sqlite')) return 'db';
  return 'app';
}

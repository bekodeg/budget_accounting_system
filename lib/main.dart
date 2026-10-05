import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/application/ports/diagnostic_log_store.dart';
import 'src/bootstrap/app_composition_root.dart';
import 'src/bootstrap/database_encryption_bootstrap.dart';
import 'src/bootstrap/runtime_bootstrap_app.dart';
import 'src/bootstrap/startup_diagnostic_exception.dart';
import 'src/data/database/app_database.dart';
import 'src/data/security/flutter_secure_database_key_store.dart';
import 'src/data/services/random_secure_token_generator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RuntimeBootstrapApp(loadRuntime: _loadRuntime));
}

Future<AppRuntime> _loadRuntime() async {
  late final DatabaseEncryptionConfig encryption;
  try {
    encryption = await DatabaseEncryptionBootstrap(
      keyStore: FlutterSecureDatabaseKeyStore(),
      tokenGenerator: RandomSecureTokenGenerator(),
    ).prepare();
  } on DatabaseKeyMissingException {
    rethrow;
  } on StartupDiagnosticException {
    rethrow;
  } on Object catch (error) {
    throw StartupDiagnosticException.fromError(
      phase: 'database-bootstrap',
      error: error,
    );
  }

  late final AppDatabase database;
  try {
    database = AppDatabase.encrypted(
      key: encryption.key,
      databasePath: encryption.databasePath,
    );
  } on Object catch (error) {
    throw StartupDiagnosticException.fromError(
      phase: 'database-create',
      error: error,
    );
  }

  late final AppCompositionRoot compositionRoot;
  try {
    compositionRoot = AppCompositionRoot.defaults(database: database);
  } on Object catch (error) {
    await database.close();
    throw StartupDiagnosticException.fromError(
      phase: 'composition-root',
      error: error,
    );
  }

  _installSafeErrorCapture(compositionRoot.services.diagnosticLogStore);
  return AppRuntime(
    services: compositionRoot.services,
    onDispose: compositionRoot.close,
  );
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

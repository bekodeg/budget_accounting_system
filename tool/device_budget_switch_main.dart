// Android acceptance entrypoint for budget switching with disposable app data.
// The native package guard must pass before opening the encrypted database.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:budget_accounting_system/src/bootstrap/app_composition_root.dart';
import 'package:budget_accounting_system/src/bootstrap/database_encryption_bootstrap.dart';
import 'package:budget_accounting_system/src/bootstrap/runtime_bootstrap_app.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/security/flutter_secure_database_key_store.dart';
import 'package:budget_accounting_system/src/data/services/random_secure_token_generator.dart';

import 'device_performance_main.dart' show verifyPerformancePackage;

const _identityChannel = MethodChannel('budget_performance/identity');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RuntimeBootstrapApp(loadRuntime: _loadRuntime));
}

Future<AppRuntime> _loadRuntime() async {
  verifyPerformancePackage(
    await _identityChannel.invokeMethod<String>('packageName'),
  );
  final config = await DatabaseEncryptionBootstrap(
    keyStore: FlutterSecureDatabaseKeyStore(),
    tokenGenerator: RandomSecureTokenGenerator(),
  ).prepare();
  final database = AppDatabase.encrypted(
    key: config.key,
    databasePath: config.databasePath,
  );
  try {
    final root = AppCompositionRoot.defaults(database: database);
    return AppRuntime(services: root.services, onDispose: root.close);
  } on Object {
    await database.close();
    rethrow;
  }
}

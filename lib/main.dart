import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/bootstrap/app_composition_root.dart';
import 'src/bootstrap/database_encryption_bootstrap.dart';
import 'src/data/database/app_database.dart';
import 'src/data/security/flutter_secure_database_key_store.dart';
import 'src/data/services/random_secure_token_generator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final encryption = await DatabaseEncryptionBootstrap(
    keyStore: FlutterSecureDatabaseKeyStore(),
    tokenGenerator: RandomSecureTokenGenerator(),
  ).prepare();
  final database = AppDatabase.encrypted(
    key: encryption.key,
    databasePath: encryption.databasePath,
  );
  final compositionRoot = AppCompositionRoot.defaults(database: database);

  runApp(
    BudgetAccountingApp(
      services: compositionRoot.services,
      onDispose: compositionRoot.close,
    ),
  );
}

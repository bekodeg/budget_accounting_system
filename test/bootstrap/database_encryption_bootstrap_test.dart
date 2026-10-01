import 'dart:io';

import 'package:budget_accounting_system/src/application/ports/database_key_store.dart';
import 'package:budget_accounting_system/src/application/ports/secure_token_generator.dart';
import 'package:budget_accounting_system/src/bootstrap/database_encryption_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late String databasePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget-db-encryption-');
    databasePath =
        '${directory.path}${Platform.pathSeparator}budget_accounting.sqlite';
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('encrypts existing plaintext database without losing data', () async {
    final plain = sqlite3.open(databasePath);
    plain.execute('CREATE TABLE sample (value TEXT NOT NULL);');
    plain.execute("INSERT INTO sample(value) VALUES ('kept');");
    plain.dispose();

    final keyStore = _KeyStore();
    final bootstrap = DatabaseEncryptionBootstrap(
      keyStore: keyStore,
      tokenGenerator: const _TokenGenerator(),
      databasePathResolver: () async => databasePath,
    );

    final config = await bootstrap.prepare();

    expect(config.migratedPlaintextDatabase, isTrue);
    expect(keyStore.key, _TokenGenerator.key);

    final withoutKey = sqlite3.open(databasePath);
    expect(
      () => withoutKey.select('SELECT value FROM sample;'),
      throwsA(isA<SqliteException>()),
    );
    withoutKey.dispose();

    final encrypted = sqlite3.open(databasePath);
    encrypted.execute("PRAGMA key = '${config.key}';");
    final rows = encrypted.select('SELECT value FROM sample;');
    expect(rows.single['value'], 'kept');
    encrypted.dispose();
  });

  test('refuses encrypted database when secure-storage key is missing', () async {
    final keyStore = _KeyStore();
    final bootstrap = DatabaseEncryptionBootstrap(
      keyStore: keyStore,
      tokenGenerator: const _TokenGenerator(),
      databasePathResolver: () async => databasePath,
    );

    final first = await bootstrap.prepare();
    final encrypted = sqlite3.open(databasePath);
    encrypted.execute("PRAGMA key = '${first.key}';");
    encrypted.execute('CREATE TABLE sample (value INTEGER NOT NULL);');
    encrypted.dispose();

    keyStore.key = null;

    await expectLater(
      bootstrap.prepare(),
      throwsA(isA<DatabaseKeyMissingException>()),
    );
  });

  test('creates and persists key for a new database', () async {
    final keyStore = _KeyStore();
    final config = await DatabaseEncryptionBootstrap(
      keyStore: keyStore,
      tokenGenerator: const _TokenGenerator(),
      databasePathResolver: () async => databasePath,
    ).prepare();

    expect(config.migratedPlaintextDatabase, isFalse);
    expect(config.key, _TokenGenerator.key);
    expect(keyStore.key, _TokenGenerator.key);
  });
}

final class _KeyStore implements DatabaseKeyStore {
  String? key;

  @override
  Future<void> deleteKey() async {
    key = null;
  }

  @override
  Future<String?> loadKey() async => key;

  @override
  Future<void> saveKey(String value) async {
    key = value;
  }
}

final class _TokenGenerator implements SecureTokenGenerator {
  const _TokenGenerator();

  static const key = 'abcdefghijklmnopqrstuvwxyzABCDEF1234567890_-';

  @override
  String nextToken({int bytes = 32}) => key;
}

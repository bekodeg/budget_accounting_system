import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../application/ports/database_key_store.dart';
import '../application/ports/secure_token_generator.dart';
import 'startup_diagnostic_exception.dart';

typedef DatabasePathResolver = Future<String> Function();

final class DatabaseEncryptionConfig {
  const DatabaseEncryptionConfig({
    required this.databasePath,
    required this.key,
    required this.migratedPlaintextDatabase,
  });

  final String databasePath;
  final String key;
  final bool migratedPlaintextDatabase;
}

final class DatabaseKeyMissingException implements Exception {
  const DatabaseKeyMissingException();

  @override
  String toString() =>
      'Encrypted database exists but its secure-storage key is missing.';
}

final class DatabaseEncryptionBootstrap {
  DatabaseEncryptionBootstrap({
    required DatabaseKeyStore keyStore,
    required SecureTokenGenerator tokenGenerator,
    DatabasePathResolver? databasePathResolver,
  }) : _keyStore = keyStore,
       _tokenGenerator = tokenGenerator,
       _databasePathResolver =
           databasePathResolver ?? _defaultDatabasePathResolver;

  final DatabaseKeyStore _keyStore;
  final SecureTokenGenerator _tokenGenerator;
  final DatabasePathResolver _databasePathResolver;

  Future<DatabaseEncryptionConfig> prepare() async {
    final path = await _guardAsync(
      phase: 'path-resolve',
      action: _databasePathResolver,
    );
    final file = File(path);
    final exists = await _guardAsync(
      phase: 'database-file-check',
      action: file.exists,
    );
    final isPlaintext = exists
        ? await _guardAsync(
            phase: 'database-header-read',
            action: () => _hasPlainSqliteHeader(file),
          )
        : false;

    var key = await _guardAsync(
      phase: 'secure-key-read',
      action: _keyStore.loadKey,
    );
    if (exists && !isPlaintext && key == null) {
      throw const DatabaseKeyMissingException();
    }

    var createdKey = false;
    if (key == null) {
      key = _tokenGenerator.nextToken(bytes: 32);
      await _guardAsync(
        phase: 'secure-key-write',
        action: () => _keyStore.saveKey(key!),
      );
      createdKey = true;
    }
    final resolvedKey = key;
    _guardSync(
      phase: 'secure-key-validate',
      action: () => _validateKey(resolvedKey),
    );

    if (isPlaintext) {
      try {
        _guardSync(
          phase: 'database-plaintext-migration',
          action: () => _encryptPlaintextDatabase(
            path: path,
            key: resolvedKey,
          ),
        );
      } on Object {
        if (createdKey) {
          try {
            await _guardAsync(
              phase: 'secure-key-cleanup',
              action: _keyStore.deleteKey,
            );
          } on Object {
            // Preserve the migration failure: it is the reason startup failed.
          }
        }
        rethrow;
      }
    }

    return DatabaseEncryptionConfig(
      databasePath: path,
      key: resolvedKey,
      migratedPlaintextDatabase: isPlaintext,
    );
  }

  Future<T> _guardAsync<T>({
    required String phase,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on DatabaseKeyMissingException {
      rethrow;
    } on StartupDiagnosticException {
      rethrow;
    } on Object catch (error) {
      throw StartupDiagnosticException.fromError(
        phase: phase,
        error: error,
      );
    }
  }

  T _guardSync<T>({
    required String phase,
    required T Function() action,
  }) {
    try {
      return action();
    } on DatabaseKeyMissingException {
      rethrow;
    } on StartupDiagnosticException {
      rethrow;
    } on Object catch (error) {
      throw StartupDiagnosticException.fromError(
        phase: phase,
        error: error,
      );
    }
  }

  static Future<String> _defaultDatabasePathResolver() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}budget_accounting.sqlite';
  }

  Future<bool> _hasPlainSqliteHeader(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(16);
      return bytes.length == 16 &&
          ascii.decode(bytes, allowInvalid: true) == 'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  void _encryptPlaintextDatabase({required String path, required String key}) {
    final database = sqlite3.open(path);
    try {
      database.execute('PRAGMA journal_mode = DELETE;');
      database.execute("PRAGMA rekey = '$key';");
      database.select('SELECT count(*) FROM sqlite_master;');
    } finally {
      database.close();
    }
  }

  void _validateKey(String key) {
    if (key.length < 32 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key)) {
      throw StateError('Stored database encryption key is invalid.');
    }
  }
}

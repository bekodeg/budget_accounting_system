import 'package:flutter/services.dart';

final class StartupDiagnosticException implements Exception {
  const StartupDiagnosticException({
    required this.phase,
    required this.causeType,
    this.platformCode,
  });

  factory StartupDiagnosticException.fromError({
    required String phase,
    required Object error,
  }) {
    if (error is StartupDiagnosticException) {
      return error;
    }
    return StartupDiagnosticException(
      phase: _sanitize(phase),
      causeType: _sanitize(error.runtimeType.toString()),
      platformCode: error is PlatformException
          ? _sanitize(error.code, fallback: 'platform-error')
          : null,
    );
  }

  final String phase;
  final String causeType;
  final String? platformCode;

  String get diagnosticCode {
    final platform = platformCode;
    return platform == null
        ? '$phase:$causeType'
        : '$phase:$causeType:$platform';
  }

  static String _sanitize(String value, {String fallback = 'unknown'}) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '-',
    );
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }

  @override
  String toString() => 'StartupDiagnosticException($diagnosticCode)';
}

final class StartupDiagnosticLocation {
  const StartupDiagnosticLocation({
    required this.className,
    required this.functionName,
    required this.operation,
    required this.dependency,
  });

  final String className;
  final String functionName;
  final String operation;
  final String dependency;
}

StartupDiagnosticLocation startupDiagnosticLocation(String diagnosticCode) {
  final phase = diagnosticCode.split(':').first;
  return switch (phase) {
    'path-resolve' => const StartupDiagnosticLocation(
      className: 'DatabaseEncryptionBootstrap',
      functionName: '_defaultDatabasePathResolver',
      operation: 'getApplicationDocumentsDirectory',
      dependency: 'path_provider / PathProviderPlugin',
    ),
    'sqlite-native-load' => const StartupDiagnosticLocation(
      className: 'DatabaseEncryptionBootstrap',
      functionName: '_verifySqlCipherBackend',
      operation: 'sqlite3.openInMemory + PRAGMA cipher_version',
      dependency: 'sqlite3 / SQLCipher',
    ),
    'secure-key-read' => const StartupDiagnosticLocation(
      className: 'FlutterSecureDatabaseKeyStore',
      functionName: 'loadKey',
      operation: 'read encrypted database key',
      dependency: 'flutter_secure_storage',
    ),
    'secure-key-write' => const StartupDiagnosticLocation(
      className: 'FlutterSecureDatabaseKeyStore',
      functionName: 'saveKey',
      operation: 'persist encrypted database key',
      dependency: 'flutter_secure_storage',
    ),
    'secure-key-validate' => const StartupDiagnosticLocation(
      className: 'DatabaseEncryptionBootstrap',
      functionName: '_validateKey',
      operation: 'validate database encryption key format',
      dependency: 'secure storage key format',
    ),
    'database-file-check' => const StartupDiagnosticLocation(
      className: 'DatabaseEncryptionBootstrap',
      functionName: 'prepare',
      operation: 'File.exists',
      dependency: 'dart:io',
    ),
    'database-header-read' => const StartupDiagnosticLocation(
      className: 'DatabaseEncryptionBootstrap',
      functionName: '_hasPlainSqliteHeader',
      operation: 'read first 16 database bytes',
      dependency: 'dart:io',
    ),
    _ => StartupDiagnosticLocation(
      className: 'runtime-bootstrap',
      functionName: phase,
      operation: phase,
      dependency: 'application runtime',
    ),
  };
}

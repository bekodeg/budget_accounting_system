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
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]'), '-');
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }

  @override
  String toString() => 'StartupDiagnosticException($diagnosticCode)';
}

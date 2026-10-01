import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/ports/diagnostic_log_store.dart';

typedef DiagnosticLogDirectoryResolver = Future<Directory> Function();

final class RotatingDiagnosticLogStore implements DiagnosticLogStore {
  RotatingDiagnosticLogStore({
    DiagnosticLogDirectoryResolver? directoryResolver,
    this.maxFileBytes = 64 * 1024,
    this.maxFiles = 3,
  }) : _directoryResolver = directoryResolver ?? _defaultDirectoryResolver;

  final DiagnosticLogDirectoryResolver _directoryResolver;
  final int maxFileBytes;
  final int maxFiles;

  static Future<Directory> _defaultDirectoryResolver() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}${Platform.pathSeparator}diagnostics');
  }

  @override
  Future<void> append({required String category, required String code}) async {
    final safeCategory = _sanitizeToken(category, fallback: 'app');
    final safeCode = _sanitizeToken(code, fallback: 'unknown_error');
    final directory = await _directoryResolver();
    await directory.create(recursive: true);

    final current = File(
      '${directory.path}${Platform.pathSeparator}diagnostic-0.jsonl',
    );
    if (await current.exists() && await current.length() >= maxFileBytes) {
      await _rotate(directory);
    }

    final record = jsonEncode({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'category': safeCategory,
      'code': safeCode,
    });
    await current.writeAsString(
      '$record\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<List<DiagnosticLogRecord>> readRecent({int limit = 100}) async {
    if (limit <= 0) return const [];
    final directory = await _directoryResolver();
    if (!await directory.exists()) return const [];

    final records = <DiagnosticLogRecord>[];
    for (var index = 0; index < maxFiles; index += 1) {
      final file = File(
        '${directory.path}${Platform.pathSeparator}diagnostic-$index.jsonl',
      );
      if (!await file.exists()) continue;

      final lines = await file.readAsLines();
      for (final line in lines.reversed) {
        final decoded = _decode(line);
        if (decoded != null) {
          records.add(decoded);
          if (records.length >= limit) return records;
        }
      }
    }
    return records;
  }

  Future<void> _rotate(Directory directory) async {
    for (var index = maxFiles - 1; index >= 0; index -= 1) {
      final source = File(
        '${directory.path}${Platform.pathSeparator}diagnostic-$index.jsonl',
      );
      if (!await source.exists()) continue;

      if (index == maxFiles - 1) {
        await source.delete();
        continue;
      }
      final target = File(
        '${directory.path}${Platform.pathSeparator}diagnostic-${index + 1}.jsonl',
      );
      if (await target.exists()) await target.delete();
      await source.rename(target.path);
    }
  }

  DiagnosticLogRecord? _decode(String line) {
    try {
      final value = jsonDecode(line);
      if (value is! Map<String, dynamic>) return null;
      final timestamp = DateTime.tryParse(value['timestamp']?.toString() ?? '');
      final category = value['category'];
      final code = value['code'];
      if (timestamp == null || category is! String || code is! String) {
        return null;
      }
      return DiagnosticLogRecord(
        timestamp: timestamp.toUtc(),
        category: category,
        code: code,
      );
    } on Object {
      return null;
    }
  }

  String _sanitizeToken(String value, {required String fallback}) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '_',
    );
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }
}

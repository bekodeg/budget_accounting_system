final class DiagnosticLogRecord {
  const DiagnosticLogRecord({
    required this.timestamp,
    required this.category,
    required this.code,
  });

  final DateTime timestamp;
  final String category;
  final String code;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'category': category,
    'code': code,
  };
}

abstract interface class DiagnosticLogStore {
  Future<void> append({required String category, required String code});

  Future<List<DiagnosticLogRecord>> readRecent({int limit = 100});
}

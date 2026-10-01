final class DiagnosticPackagePreview {
  const DiagnosticPackagePreview({
    required this.appVersion,
    required this.schemaVersion,
    required this.snapshotProtocolVersion,
    required this.platform,
    required this.budgetCount,
    required this.syncOperationCount,
    required this.failedReceiptCount,
    required this.recentErrorCount,
    required this.archiveEntries,
  });

  final String appVersion;
  final int schemaVersion;
  final int snapshotProtocolVersion;
  final String platform;
  final int budgetCount;
  final int syncOperationCount;
  final int failedReceiptCount;
  final int recentErrorCount;
  final List<String> archiveEntries;
}

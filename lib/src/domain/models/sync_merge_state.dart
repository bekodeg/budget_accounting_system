final class SyncVersion implements Comparable<SyncVersion> {
  const SyncVersion({
    required this.logicalClock,
    required this.deviceId,
  });

  final BigInt logicalClock;
  final String deviceId;

  @override
  int compareTo(SyncVersion other) {
    final clockComparison = logicalClock.compareTo(other.logicalClock);
    if (clockComparison != 0) return clockComparison;
    return deviceId.compareTo(other.deviceId);
  }

  bool isNewerThan(SyncVersion? other) =>
      other == null || compareTo(other) > 0;

  bool isAtLeastAsNewAs(SyncVersion? other) =>
      other == null || compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncVersion &&
          other.logicalClock == logicalClock &&
          other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(logicalClock, deviceId);
}

final class SyncFieldState {
  const SyncFieldState({
    required this.value,
    required this.version,
    required this.operationId,
  });

  final Object? value;
  final SyncVersion version;
  final String operationId;
}

final class MergedSyncEntityState {
  const MergedSyncEntityState({
    required this.fields,
    required this.tombstoneVersion,
    required this.latestWriteVersion,
    required this.appliedOperationIds,
  });

  final Map<String, SyncFieldState> fields;
  final SyncVersion? tombstoneVersion;
  final SyncVersion? latestWriteVersion;
  final Set<String> appliedOperationIds;

  bool get isDeleted {
    final tombstone = tombstoneVersion;
    if (tombstone == null) return false;
    return tombstone.isAtLeastAsNewAs(latestWriteVersion);
  }

  Map<String, Object?> get values => {
    for (final entry in fields.entries) entry.key: entry.value.value,
  };
}

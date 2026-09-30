final class SyncCoordinatorTopology {
  const SyncCoordinatorTopology({
    required this.coordinatorDeviceId,
    required this.peerDeviceIds,
  });

  final String coordinatorDeviceId;
  final List<String> peerDeviceIds;
}

final class SyncCoordinatorMetrics {
  const SyncCoordinatorMetrics({
    required this.coordinatorDeviceId,
    required this.completedPairSessions,
    required this.failedPeerDeviceIds,
    required this.failovers,
  });

  final String coordinatorDeviceId;
  final int completedPairSessions;
  final Set<String> failedPeerDeviceIds;
  final int failovers;
}

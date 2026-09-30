import 'dart:async';

import '../../domain/models/sync_coordinator.dart';
import '../errors/sync_coordinator_error.dart';

typedef PairSync = Future<void> Function({
  required String coordinatorDeviceId,
  required String peerDeviceId,
});

final class SyncCoordinatorService {
  const SyncCoordinatorService({
    this.maxConcurrentConnections = 4,
  }) : assert(maxConcurrentConnections > 0);

  final int maxConcurrentConnections;

  SyncCoordinatorTopology plan(Iterable<String> deviceIds) {
    final devices = deviceIds.toSet().toList()..sort();
    if (devices.isEmpty) {
      throw const SyncCoordinatorError(
        SyncCoordinatorErrorCode.noPeers,
        'Нельзя выбрать координатор без доступных устройств.',
      );
    }

    return SyncCoordinatorTopology(
      coordinatorDeviceId: devices.first,
      peerDeviceIds: List.unmodifiable(devices.skip(1)),
    );
  }

  Future<SyncCoordinatorMetrics> synchronize({
    required Iterable<String> availableDeviceIds,
    required PairSync synchronizePair,
  }) async {
    final available = availableDeviceIds.toSet();
    if (available.isEmpty) {
      throw const SyncCoordinatorError(
        SyncCoordinatorErrorCode.noPeers,
        'Нет доступных устройств для sync-сессии.',
      );
    }

    final failed = <String>{};
    var completed = 0;
    var failovers = 0;

    while (available.length > 1) {
      final topology = plan(available);
      final coordinator = topology.coordinatorDeviceId;

      try {
        completed += await _runPass(
          coordinatorDeviceId: coordinator,
          peerDeviceIds: topology.peerDeviceIds,
          synchronizePair: synchronizePair,
          failedPeerDeviceIds: failed,
          availableDeviceIds: available,
        );

        // Fan-out repeats pairwise sync after the coordinator has collected
        // operations from every reachable peer. Peers therefore receive the
        // union accumulated by the coordinator without making it authoritative.
        final survivors = topology.peerDeviceIds
            .where(available.contains)
            .toList(growable: false);
        completed += await _runPass(
          coordinatorDeviceId: coordinator,
          peerDeviceIds: survivors,
          synchronizePair: synchronizePair,
          failedPeerDeviceIds: failed,
          availableDeviceIds: available,
        );
        return SyncCoordinatorMetrics(
          coordinatorDeviceId: coordinator,
          completedPairSessions: completed,
          failedPeerDeviceIds: Set.unmodifiable(failed),
          failovers: failovers,
        );
      } on SyncCoordinatorError catch (error) {
        if (error.code != SyncCoordinatorErrorCode.coordinatorUnavailable ||
            error.deviceId != coordinator) {
          rethrow;
        }
        available.remove(coordinator);
        failed.add(coordinator);
        failovers += 1;
      }
    }

    final survivor = available.single;
    return SyncCoordinatorMetrics(
      coordinatorDeviceId: survivor,
      completedPairSessions: completed,
      failedPeerDeviceIds: Set.unmodifiable(failed),
      failovers: failovers,
    );
  }

  Future<int> _runPass({
    required String coordinatorDeviceId,
    required List<String> peerDeviceIds,
    required PairSync synchronizePair,
    required Set<String> failedPeerDeviceIds,
    required Set<String> availableDeviceIds,
  }) async {
    var completed = 0;

    for (var offset = 0;
        offset < peerDeviceIds.length;
        offset += maxConcurrentConnections) {
      final group = peerDeviceIds
          .skip(offset)
          .take(maxConcurrentConnections)
          .where(availableDeviceIds.contains)
          .toList(growable: false);

      final results = await Future.wait(
        group.map((peerDeviceId) async {
          try {
            await synchronizePair(
              coordinatorDeviceId: coordinatorDeviceId,
              peerDeviceId: peerDeviceId,
            );
            return _PairResult(peerDeviceId, true, null);
          } on SyncCoordinatorError catch (error) {
            return _PairResult(peerDeviceId, false, error);
          } on Object {
            return _PairResult(peerDeviceId, false, null);
          }
        }),
      );

      for (final result in results) {
        if (result.succeeded) {
          completed += 1;
          continue;
        }

        final error = result.error;
        if (error?.code == SyncCoordinatorErrorCode.coordinatorUnavailable &&
            error?.deviceId == coordinatorDeviceId) {
          throw error!;
        }

        availableDeviceIds.remove(result.peerDeviceId);
        failedPeerDeviceIds.add(result.peerDeviceId);
      }
    }

    return completed;
  }
}

final class _PairResult {
  const _PairResult(this.peerDeviceId, this.succeeded, this.error);

  final String peerDeviceId;
  final bool succeeded;
  final SyncCoordinatorError? error;
}

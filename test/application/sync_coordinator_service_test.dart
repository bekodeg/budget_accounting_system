import 'package:budget_accounting_system/src/application/errors/sync_coordinator_error.dart';
import 'package:budget_accounting_system/src/application/services/sync_coordinator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('elects the same coordinator independent of discovery order', () {
    const service = SyncCoordinatorService();

    final first = service.plan(['device-c', 'device-a', 'device-b']);
    final second = service.plan(['device-b', 'device-c', 'device-a']);

    expect(first.coordinatorDeviceId, 'device-a');
    expect(second.coordinatorDeviceId, 'device-a');
    expect(first.peerDeviceIds, ['device-b', 'device-c']);
  });

  test('fan-in and fan-out converge all simulated peers', () async {
    const service = SyncCoordinatorService(maxConcurrentConnections: 2);
    final journals = <String, Set<String>>{
      'device-a': {'a-1'},
      'device-b': {'b-1'},
      'device-c': {'c-1'},
      'device-d': {'d-1'},
    };

    Future<void> pair({
      required String coordinatorDeviceId,
      required String peerDeviceId,
    }) async {
      final union = <String>{
        ...journals[coordinatorDeviceId]!,
        ...journals[peerDeviceId]!,
      };
      journals[coordinatorDeviceId]!
        ..clear()
        ..addAll(union);
      journals[peerDeviceId]!
        ..clear()
        ..addAll(union);
    }

    final metrics = await service.synchronize(
      availableDeviceIds: journals.keys,
      synchronizePair: pair,
    );

    expect(metrics.coordinatorDeviceId, 'device-a');
    expect(metrics.completedPairSessions, 6);
    for (final journal in journals.values) {
      expect(journal, {'a-1', 'b-1', 'c-1', 'd-1'});
    }
  });

  test('limits simultaneous peer sessions', () async {
    const service = SyncCoordinatorService(maxConcurrentConnections: 2);
    var active = 0;
    var maxActive = 0;

    Future<void> pair({
      required String coordinatorDeviceId,
      required String peerDeviceId,
    }) async {
      active += 1;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active -= 1;
    }

    await service.synchronize(
      availableDeviceIds: [
        'device-a',
        'device-b',
        'device-c',
        'device-d',
        'device-e',
      ],
      synchronizePair: pair,
    );

    expect(maxActive, lessThanOrEqualTo(2));
  });

  test('elects a new coordinator after coordinator loss', () async {
    const service = SyncCoordinatorService(maxConcurrentConnections: 1);
    final calls = <String>[];
    var failedA = false;

    Future<void> pair({
      required String coordinatorDeviceId,
      required String peerDeviceId,
    }) async {
      calls.add('$coordinatorDeviceId->$peerDeviceId');
      if (coordinatorDeviceId == 'device-a' && !failedA) {
        failedA = true;
        throw const SyncCoordinatorError(
          SyncCoordinatorErrorCode.coordinatorUnavailable,
          'Coordinator disconnected.',
          deviceId: 'device-a',
        );
      }
    }

    final result = await service.synchronize(
      availableDeviceIds: ['device-c', 'device-a', 'device-b'],
      synchronizePair: pair,
    );

    expect(result.coordinatorDeviceId, 'device-b');
    expect(result.failovers, 1);
    expect(result.failedPeerDeviceIds, contains('device-a'));
    expect(calls, contains('device-b->device-c'));
  });

  test('peer loss does not abort remaining sync', () async {
    const service = SyncCoordinatorService(maxConcurrentConnections: 1);

    Future<void> pair({
      required String coordinatorDeviceId,
      required String peerDeviceId,
    }) async {
      if (peerDeviceId == 'device-c') {
        throw StateError('peer disconnected');
      }
    }

    final result = await service.synchronize(
      availableDeviceIds: ['device-a', 'device-b', 'device-c', 'device-d'],
      synchronizePair: pair,
    );

    expect(result.failedPeerDeviceIds, {'device-c'});
    expect(result.coordinatorDeviceId, 'device-a');
  });
}

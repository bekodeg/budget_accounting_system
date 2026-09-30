import 'dart:async';

import 'package:budget_accounting_system/src/application/errors/sync_protocol_error.dart';
import 'package:budget_accounting_system/src/application/ports/secure_lan_channel.dart';
import 'package:budget_accounting_system/src/application/ports/sync_journal.dart';
import 'package:budget_accounting_system/src/application/services/sync_merge_engine.dart';
import 'package:budget_accounting_system/src/application/services/sync_session_service.dart';
import 'package:budget_accounting_system/src/domain/models/lan_session.dart';
import 'package:budget_accounting_system/src/domain/models/sync_mutation.dart';
import 'package:budget_accounting_system/src/domain/models/sync_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const budgetId = 'budget-1';

  test('two peers converge and second sync sends no history', () async {
    final journalA = _MemoryJournal([
      _op('a-1', device: 'device-a', clock: 1),
      _op('a-2', device: 'device-a', clock: 2),
      _op('a-3', device: 'device-a', clock: 3),
    ]);
    final journalB = _MemoryJournal([
      _op('b-1', device: 'device-b', clock: 1),
      _op('b-2', device: 'device-b', clock: 2),
    ]);
    final serviceA = SyncSessionService(journal: journalA, batchSize: 2);
    final serviceB = SyncSessionService(journal: journalB, batchSize: 2);

    final firstPair = _channelPair();
    final firstMetrics = await Future.wait([
      serviceA.synchronize(
        channel: firstPair.a,
        budgetId: budgetId,
        localDeviceId: 'device-a',
      ),
      serviceB.synchronize(
        channel: firstPair.b,
        budgetId: budgetId,
        localDeviceId: 'device-b',
      ),
    ]);

    expect(journalA.operationIds, {'a-1', 'a-2', 'a-3', 'b-1', 'b-2'});
    expect(journalB.operationIds, journalA.operationIds);
    expect(
      await journalA.stateVector(budgetId),
      await journalB.stateVector(budgetId),
    );
    const mergeEngine = SyncMergeEngine();
    final mergedA = mergeEngine.merge(journalA.signedOperations);
    final mergedB = mergeEngine.merge(journalB.signedOperations);
    expect(mergedA.values, mergedB.values);
    expect(mergedA.isDeleted, mergedB.isDeleted);
    expect(firstMetrics[0].sentBatches, greaterThanOrEqualTo(2));
    expect(firstMetrics[0].sentOperations, 3);
    expect(firstMetrics[1].sentOperations, 2);

    final secondPair = _channelPair();
    final secondMetrics = await Future.wait([
      serviceA.synchronize(
        channel: secondPair.a,
        budgetId: budgetId,
        localDeviceId: 'device-a',
      ),
      serviceB.synchronize(
        channel: secondPair.b,
        budgetId: budgetId,
        localDeviceId: 'device-b',
      ),
    ]);

    expect(secondMetrics[0].sentOperations, 0);
    expect(secondMetrics[1].sentOperations, 0);
    expect(secondMetrics[0].sentBatches, 1);
    expect(secondMetrics[1].sentBatches, 1);
  });

  test('interrupted session safely resumes from updated state vectors', () async {
    final journalA = _MemoryJournal([
      _op('a-1', device: 'device-a', clock: 1),
      _op('a-2', device: 'device-a', clock: 2),
      _op('a-3', device: 'device-a', clock: 3),
    ]);
    final journalB = _MemoryJournal();
    final serviceA = SyncSessionService(journal: journalA, batchSize: 1);
    final serviceB = SyncSessionService(journal: journalB, batchSize: 1);

    final broken = _channelPair(failASendNumber: 3);
    await expectLater(
      Future.wait([
        serviceA.synchronize(
          channel: broken.a,
          budgetId: budgetId,
          localDeviceId: 'device-a',
        ),
        serviceB.synchronize(
          channel: broken.b,
          budgetId: budgetId,
          localDeviceId: 'device-b',
        ),
      ]),
      throwsA(anything),
    );

    final beforeRetryCount = journalB.operationIds.length;

    final retry = _channelPair();
    await Future.wait([
      serviceA.synchronize(
        channel: retry.a,
        budgetId: budgetId,
        localDeviceId: 'device-a',
      ),
      serviceB.synchronize(
        channel: retry.b,
        budgetId: budgetId,
        localDeviceId: 'device-b',
      ),
    ]);

    expect(beforeRetryCount, greaterThanOrEqualTo(1));
    expect(journalB.operationIds, journalA.operationIds);
  });

  test('three peers converge through pairwise sessions', () async {
    final a = _MemoryJournal([_op('a-1', device: 'device-a', clock: 1)]);
    final b = _MemoryJournal([_op('b-1', device: 'device-b', clock: 1)]);
    final c = _MemoryJournal([_op('c-1', device: 'device-c', clock: 1)]);

    Future<void> syncPair(
      _MemoryJournal left,
      String leftDevice,
      _MemoryJournal right,
      String rightDevice,
    ) async {
      final pair = _channelPair(
        aDevice: leftDevice,
        bDevice: rightDevice,
      );
      await Future.wait([
        SyncSessionService(journal: left).synchronize(
          channel: pair.a,
          budgetId: budgetId,
          localDeviceId: leftDevice,
        ),
        SyncSessionService(journal: right).synchronize(
          channel: pair.b,
          budgetId: budgetId,
          localDeviceId: rightDevice,
        ),
      ]);
    }

    await syncPair(a, 'device-a', b, 'device-b');
    await syncPair(b, 'device-b', c, 'device-c');
    await syncPair(a, 'device-a', c, 'device-c');

    expect(a.operationIds, {'a-1', 'b-1', 'c-1'});
    expect(b.operationIds, a.operationIds);
    expect(c.operationIds, a.operationIds);
  });

  test('authenticated channel peer must match protocol hello device', () async {
    final journalA = _MemoryJournal();
    final journalB = _MemoryJournal();
    final pair = _channelPair(
      aRemoteDeviceOverride: 'unexpected-device',
    );

    await expectLater(
      Future.wait([
        SyncSessionService(journal: journalA).synchronize(
          channel: pair.a,
          budgetId: budgetId,
          localDeviceId: 'device-a',
        ),
        SyncSessionService(journal: journalB).synchronize(
          channel: pair.b,
          budgetId: budgetId,
          localDeviceId: 'device-b',
        ),
      ]),
      throwsA(
        isA<SyncProtocolError>().having(
          (error) => error.code,
          'code',
          SyncProtocolErrorCode.invalidMessage,
        ),
      ),
    );
  });
}

SyncWireOperation _op(
  String id, {
  required String device,
  required int clock,
}) {
  return SyncWireOperation(
    operation: SignedSyncOperation(
      operationId: id,
      budgetId: 'budget-1',
      entityType: 'category',
      entityId: 'category-1',
      type: SyncMutationType.patch,
      patchJson: '{"value":"$id"}',
      authorId: 'user-$device',
      deviceId: device,
      logicalClock: BigInt.from(clock),
      createdAt: DateTime.utc(2026, 9, 30, 10, clock),
    ),
    signature: 'signature-$id',
  );
}

final class _MemoryJournal implements SyncJournal {
  _MemoryJournal([List<SyncWireOperation> operations = const []])
    : _operations = {
        for (final operation in operations)
          operation.operation.operationId: operation,
      };

  final Map<String, SyncWireOperation> _operations;

  Set<String> get operationIds => Set.unmodifiable(_operations.keys);

  List<SignedSyncOperation> get signedOperations => _operations.values
      .map((wire) => wire.operation)
      .toList(growable: false);

  @override
  Future<SyncStateVector> stateVector(String budgetId) async {
    final clocks = <String, BigInt>{};
    for (final wire in _operations.values) {
      final operation = wire.operation;
      if (operation.budgetId != budgetId) continue;
      final current = clocks[operation.deviceId] ?? BigInt.zero;
      if (operation.logicalClock > current) {
        clocks[operation.deviceId] = operation.logicalClock;
      }
    }
    return SyncStateVector(clocks);
  }

  @override
  Future<SyncOperationPage> missingOperations({
    required String budgetId,
    required SyncStateVector remoteState,
    required int limit,
  }) async {
    final missing = _operations.values.where((wire) {
      final operation = wire.operation;
      return operation.budgetId == budgetId &&
          operation.logicalClock > remoteState.clockFor(operation.deviceId);
    }).toList()
      ..sort((left, right) {
        final clock = left.operation.logicalClock.compareTo(
          right.operation.logicalClock,
        );
        if (clock != 0) return clock;
        final device = left.operation.deviceId.compareTo(
          right.operation.deviceId,
        );
        if (device != 0) return device;
        return left.operation.operationId.compareTo(
          right.operation.operationId,
        );
      });

    return SyncOperationPage(
      operations: missing.take(limit).toList(growable: false),
      hasMore: missing.length > limit,
    );
  }

  @override
  Future<SyncIngestResult> ingest({
    required String budgetId,
    required List<SyncWireOperation> operations,
  }) async {
    var inserted = 0;
    var duplicates = 0;
    for (final wire in operations) {
      if (wire.operation.budgetId != budgetId) {
        throw const SyncProtocolError(
          SyncProtocolErrorCode.budgetMismatch,
          'Wrong budget.',
        );
      }
      final id = wire.operation.operationId;
      final existing = _operations[id];
      if (existing != null) {
        if (existing != wire) {
          throw const SyncProtocolError(
            SyncProtocolErrorCode.operationCollision,
            'Operation collision.',
          );
        }
        duplicates += 1;
        continue;
      }
      _operations[id] = wire;
      inserted += 1;
    }
    return SyncIngestResult(inserted: inserted, duplicates: duplicates);
  }
}

({ _MemorySecureChannel a, _MemorySecureChannel b }) _channelPair({
  String aDevice = 'device-a',
  String bDevice = 'device-b',
  String? aRemoteDeviceOverride,
  int? failASendNumber,
}) {
  final a = _MemorySecureChannel(
    remotePeer: _peer(aRemoteDeviceOverride ?? bDevice),
    failSendNumber: failASendNumber,
  );
  final b = _MemorySecureChannel(remotePeer: _peer(aDevice));
  a.peer = b;
  b.peer = a;
  return (a: a, b: b);
}

LanPeerDescriptor _peer(String deviceId) {
  return LanPeerDescriptor(
    budgetId: 'budget-1',
    userId: 'user-$deviceId',
    deviceId: deviceId,
    publicKey: 'ed25519:$deviceId',
    nonce: 'nonce-$deviceId',
  );
}

final class _MemorySecureChannel implements SecureLanChannel {
  _MemorySecureChannel({
    required this.remotePeer,
    this.failSendNumber,
  });

  @override
  final LanPeerDescriptor remotePeer;

  final int? failSendNumber;
  late _MemorySecureChannel peer;
  final List<List<int>> _queue = [];
  final List<Completer<List<int>>> _waiters = [];
  Object? _terminalError;
  var _sendCount = 0;

  @override
  Future<void> send(List<int> clearText) async {
    _sendCount += 1;
    if (failSendNumber == _sendCount) {
      final error = StateError('simulated transport interruption');
      _fail(error);
      peer._fail(error);
      throw error;
    }
    final error = _terminalError;
    if (error != null) throw error;
    peer._deliver(List<int>.unmodifiable(clearText));
  }

  void _deliver(List<int> value) {
    final error = _terminalError;
    if (error != null) return;
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(value);
    } else {
      _queue.add(value);
    }
  }

  @override
  Future<List<int>> receive() {
    if (_queue.isNotEmpty) {
      return Future.value(_queue.removeAt(0));
    }
    final error = _terminalError;
    if (error != null) return Future.error(error);
    final completer = Completer<List<int>>();
    _waiters.add(completer);
    return completer.future;
  }

  void _fail(Object error) {
    _terminalError ??= error;
    while (_waiters.isNotEmpty) {
      _waiters.removeAt(0).completeError(error);
    }
  }

  @override
  Future<void> close() async {
    final error = StateError('channel closed');
    _fail(error);
    peer._fail(error);
  }
}

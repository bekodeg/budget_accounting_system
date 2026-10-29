import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:budget_accounting_system/src/application/errors/budget_snapshot_error.dart';
import 'package:budget_accounting_system/src/application/ports/budget_snapshot_compaction_hook.dart';
import 'package:budget_accounting_system/src/application/ports/budget_snapshot_repository.dart';
import 'package:budget_accounting_system/src/application/ports/secure_lan_channel.dart';
import 'package:budget_accounting_system/src/application/services/budget_snapshot_session_service.dart';
import 'package:budget_accounting_system/src/domain/models/budget_snapshot.dart';
import 'package:budget_accounting_system/src/domain/models/lan_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const budgetId = 'budget-1';
  const snapshot = BudgetSnapshotPackage(
    bodyJson: '{"budget_id":"budget-1"}',
    digestBase64: 'digest-1',
  );

  test('transfers snapshot and compacts only after matching ack', () async {
    final sender = _Repository(snapshot);
    final receiver = _Repository(null);
    final compaction = _CompactionHook();
    final channels = _channelPair();

    await Future.wait([
      BudgetSnapshotSessionService(
        sender,
        compactionHook: compaction,
      ).send(channel: channels.sender, budgetId: budgetId),
      BudgetSnapshotSessionService(
        receiver,
      ).receiveAndApply(channel: channels.receiver, budgetId: budgetId),
    ]);

    expect(sender.createdBudgetId, budgetId);
    expect(receiver.appliedBudgetId, budgetId);
    expect(receiver.appliedSnapshot?.bodyJson, snapshot.bodyJson);
    expect(receiver.appliedSnapshot?.digestBase64, snapshot.digestBase64);
    expect(compaction.confirmedBudgetId, budgetId);
    expect(compaction.confirmedSnapshot, same(snapshot));
  });

  test('rejects a mismatched ack without compacting', () async {
    final compaction = _CompactionHook();
    final channel = _Channel()
      ..enqueue(
        utf8.encode(
          jsonEncode({
            'v': BudgetSnapshotSessionService.protocolVersion,
            'type': 'snapshot_ack',
            'budget_id': budgetId,
            'digest': 'wrong-digest',
          }),
        ),
      );

    await expectLater(
      BudgetSnapshotSessionService(
        _Repository(snapshot),
        compactionHook: compaction,
      ).send(channel: channel, budgetId: budgetId),
      throwsA(
        isA<BudgetSnapshotError>().having(
          (error) => error.code,
          'code',
          BudgetSnapshotErrorCode.invalidFormat,
        ),
      ),
    );
    expect(channel.sent, hasLength(1));
    expect(compaction.confirmedBudgetId, isNull);
  });

  test('rejects malformed snapshot before applying or acknowledging', () async {
    final repository = _Repository(null);
    final channel = _Channel()..enqueue(utf8.encode('{bad json'));

    await expectLater(
      BudgetSnapshotSessionService(
        repository,
      ).receiveAndApply(channel: channel, budgetId: budgetId),
      throwsA(isA<BudgetSnapshotError>()),
    );
    expect(repository.appliedSnapshot, isNull);
    expect(channel.sent, isEmpty);
  });
}

final class _Repository implements BudgetSnapshotRepository {
  _Repository(this.snapshot);

  final BudgetSnapshotPackage? snapshot;
  String? createdBudgetId;
  String? appliedBudgetId;
  BudgetSnapshotPackage? appliedSnapshot;

  @override
  Future<BudgetSnapshotPackage> create(String budgetId) async {
    createdBudgetId = budgetId;
    return snapshot!;
  }

  @override
  Future<void> apply({
    required String expectedBudgetId,
    required BudgetSnapshotPackage snapshot,
  }) async {
    appliedBudgetId = expectedBudgetId;
    appliedSnapshot = snapshot;
  }
}

final class _CompactionHook implements BudgetSnapshotCompactionHook {
  String? confirmedBudgetId;
  BudgetSnapshotPackage? confirmedSnapshot;

  @override
  Future<void> onSnapshotConfirmed({
    required String budgetId,
    required BudgetSnapshotPackage snapshot,
  }) async {
    confirmedBudgetId = budgetId;
    confirmedSnapshot = snapshot;
  }
}

({_Channel sender, _Channel receiver}) _channelPair() {
  final sender = _Channel();
  final receiver = _Channel();
  sender.peer = receiver;
  receiver.peer = sender;
  return (sender: sender, receiver: receiver);
}

final class _Channel implements SecureLanChannel {
  _Channel();

  _Channel? peer;
  final _queue = Queue<List<int>>();
  final _waiters = Queue<Completer<List<int>>>();
  final sent = <List<int>>[];

  @override
  LanPeerDescriptor get remotePeer => const LanPeerDescriptor(
    budgetId: 'budget-1',
    userId: 'user-1',
    deviceId: 'device-1',
    publicKey: 'key-1',
    nonce: 'nonce-1',
  );

  void enqueue(List<int> bytes) {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(bytes);
    } else {
      _queue.add(bytes);
    }
  }

  @override
  Future<void> send(List<int> clearText) async {
    sent.add(clearText);
    peer?.enqueue(clearText);
  }

  @override
  Future<List<int>> receive() {
    if (_queue.isNotEmpty) return Future.value(_queue.removeFirst());
    final waiter = Completer<List<int>>();
    _waiters.add(waiter);
    return waiter.future;
  }

  @override
  Future<void> close() async {}
}

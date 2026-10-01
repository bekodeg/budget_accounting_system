import 'dart:convert';

import '../../domain/models/budget_snapshot.dart';
import '../errors/budget_snapshot_error.dart';
import '../ports/budget_snapshot_compaction_hook.dart';
import '../ports/budget_snapshot_repository.dart';
import '../ports/secure_lan_channel.dart';

final class BudgetSnapshotSessionService {
  const BudgetSnapshotSessionService(
    this._repository, {
    BudgetSnapshotCompactionHook? compactionHook,
  }) : _compactionHook = compactionHook;

  static const protocolVersion = 1;

  final BudgetSnapshotRepository _repository;
  final BudgetSnapshotCompactionHook? _compactionHook;

  Future<void> send({
    required SecureLanChannel channel,
    required String budgetId,
  }) async {
    final snapshot = await _repository.create(budgetId);
    await channel.send(
      utf8.encode(
        jsonEncode({
          'v': protocolVersion,
          'type': 'budget_snapshot',
          'budget_id': budgetId,
          'body': snapshot.bodyJson,
          'digest': snapshot.digestBase64,
        }),
      ),
    );

    final ack = _decodeFrame(await channel.receive());
    if (ack['v'] != protocolVersion ||
        ack['type'] != 'snapshot_ack' ||
        ack['budget_id'] != budgetId ||
        ack['digest'] != snapshot.digestBase64) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot acknowledgement is invalid.',
      );
    }

    final hook = _compactionHook;
    if (hook != null) {
      await hook.onSnapshotConfirmed(
        budgetId: budgetId,
        snapshot: snapshot,
      );
    }
  }

  Future<void> receiveAndApply({
    required SecureLanChannel channel,
    required String budgetId,
  }) async {
    final decoded = _decodeFrame(await channel.receive());
    if (decoded['v'] != protocolVersion ||
        decoded['type'] != 'budget_snapshot' ||
        decoded['budget_id'] != budgetId ||
        decoded['body'] is! String ||
        decoded['digest'] is! String) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot transport frame has invalid fields.',
      );
    }

    final snapshot = BudgetSnapshotPackage(
      bodyJson: decoded['body'] as String,
      digestBase64: decoded['digest'] as String,
    );
    await _repository.apply(
      expectedBudgetId: budgetId,
      snapshot: snapshot,
    );
    await channel.send(
      utf8.encode(
        jsonEncode({
          'v': protocolVersion,
          'type': 'snapshot_ack',
          'budget_id': budgetId,
          'digest': snapshot.digestBase64,
        }),
      ),
    );
  }

  Map<String, dynamic> _decodeFrame(List<int> bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot transport frame is invalid.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot transport frame must be an object.',
      );
    }
    return decoded;
  }
}

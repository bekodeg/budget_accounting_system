import 'dart:convert';

import '../../domain/models/budget_snapshot.dart';
import '../errors/budget_snapshot_error.dart';
import '../ports/budget_snapshot_repository.dart';
import '../ports/secure_lan_channel.dart';

final class BudgetSnapshotSessionService {
  const BudgetSnapshotSessionService(this._repository);

  static const protocolVersion = 1;

  final BudgetSnapshotRepository _repository;

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
  }

  Future<void> receiveAndApply({
    required SecureLanChannel channel,
    required String budgetId,
  }) async {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(await channel.receive()));
    } on Object {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot transport frame is invalid.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['v'] != protocolVersion ||
        decoded['type'] != 'budget_snapshot' ||
        decoded['budget_id'] != budgetId ||
        decoded['body'] is! String ||
        decoded['digest'] is! String) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot transport frame has invalid fields.',
      );
    }

    await _repository.apply(
      expectedBudgetId: budgetId,
      snapshot: BudgetSnapshotPackage(
        bodyJson: decoded['body'] as String,
        digestBase64: decoded['digest'] as String,
      ),
    );
  }
}

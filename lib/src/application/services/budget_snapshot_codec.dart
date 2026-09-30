import 'dart:collection';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/budget_snapshot.dart';
import '../errors/budget_snapshot_error.dart';

final class DecodedBudgetSnapshot {
  const DecodedBudgetSnapshot({
    required this.metadata,
    required this.body,
  });

  final BudgetSnapshotMetadata metadata;
  final Map<String, dynamic> body;
}

final class BudgetSnapshotCodec {
  const BudgetSnapshotCodec();

  static const currentVersion = 1;

  Future<BudgetSnapshotPackage> encode(Map<String, Object?> body) async {
    final canonical = _canonicalJson(body);
    final hash = await Sha256().hash(utf8.encode(canonical));
    return BudgetSnapshotPackage(
      bodyJson: canonical,
      digestBase64: base64Url.encode(hash.bytes),
    );
  }

  Future<DecodedBudgetSnapshot> decodeAndVerify({
    required String expectedBudgetId,
    required BudgetSnapshotPackage snapshot,
  }) async {
    final hash = await Sha256().hash(utf8.encode(snapshot.bodyJson));
    final actualDigest = base64Url.encode(hash.bytes);
    if (actualDigest != snapshot.digestBase64) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.digestMismatch,
        'Snapshot checksum does not match its payload.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(snapshot.bodyJson);
    } on Object {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot body must be valid JSON.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot body must be a JSON object.',
      );
    }

    final version = decoded['v'];
    if (version != currentVersion) {
      throw BudgetSnapshotError(
        BudgetSnapshotErrorCode.unsupportedVersion,
        'Unsupported snapshot version: $version.',
      );
    }

    final budgetId = decoded['budget_id'];
    if (budgetId is! String || budgetId != expectedBudgetId) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.budgetMismatch,
        'Snapshot belongs to another budget.',
      );
    }

    final createdAtRaw = decoded['created_at'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)
        : null;
    if (createdAt == null) {
      throw const BudgetSnapshotError(
        BudgetSnapshotErrorCode.invalidFormat,
        'Snapshot created_at is invalid.',
      );
    }

    return DecodedBudgetSnapshot(
      metadata: BudgetSnapshotMetadata(
        version: version as int,
        budgetId: budgetId,
        createdAt: createdAt.toUtc(),
      ),
      body: decoded,
    );
  }
}

String _canonicalJson(Object? value) {
  Object? sort(Object? current) {
    if (current is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in current.entries) {
        sorted[entry.key.toString()] = sort(entry.value);
      }
      return sorted;
    }
    if (current is List) {
      return current.map(sort).toList(growable: false);
    }
    if (current is BigInt) return current.toString();
    if (current is DateTime) return current.toUtc().toIso8601String();
    return current;
  }

  return jsonEncode(sort(value));
}

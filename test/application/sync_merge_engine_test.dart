import 'package:budget_accounting_system/src/application/errors/sync_merge_error.dart';
import 'package:budget_accounting_system/src/application/services/sync_merge_engine.dart';
import 'package:budget_accounting_system/src/domain/models/sync_mutation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = SyncMergeEngine();

  test('merges concurrent updates to different fields independently', () {
    final result = engine.merge([
      _op(
        id: 'op-name',
        clock: 2,
        device: 'device-a',
        patch: '{"name":"Groceries"}',
      ),
      _op(
        id: 'op-kind',
        clock: 2,
        device: 'device-b',
        patch: '{"kind":"EXPENSE"}',
      ),
    ]);

    expect(result.values, {
      'name': 'Groceries',
      'kind': 'EXPENSE',
    });
    expect(result.isDeleted, isFalse);
  });

  test('same field uses logical clock then device id as deterministic LWW', () {
    final result = engine.merge([
      _op(
        id: 'op-a',
        clock: 4,
        device: 'device-a',
        patch: '{"name":"A"}',
      ),
      _op(
        id: 'op-b',
        clock: 4,
        device: 'device-b',
        patch: '{"name":"B"}',
      ),
      _op(
        id: 'op-old',
        clock: 3,
        device: 'device-z',
        patch: '{"name":"Old"}',
      ),
    ]);

    expect(result.values['name'], 'B');
    expect(result.fields['name']!.operationId, 'op-b');
  });

  test('all delivery orders converge to the same state', () {
    final operations = [
      _op(
        id: 'op-base',
        clock: 1,
        device: 'device-a',
        patch: '{"name":"Food","kind":"EXPENSE","archived":false}',
      ),
      _op(
        id: 'op-name',
        clock: 2,
        device: 'device-a',
        patch: '{"name":"Groceries"}',
      ),
      _op(
        id: 'op-archive',
        clock: 2,
        device: 'device-b',
        patch: '{"archived":true}',
      ),
    ];

    final states = _permutations(operations)
        .map(engine.merge)
        .toList(growable: false);

    for (final state in states) {
      expect(state.values, states.first.values);
      expect(state.isDeleted, states.first.isDeleted);
      expect(state.appliedOperationIds, states.first.appliedOperationIds);
    }
  });

  test('duplicate delivery of the same op id is idempotent', () {
    final operation = _op(
      id: 'op-1',
      clock: 1,
      device: 'device-a',
      patch: '{"name":"Food"}',
    );

    final result = engine.merge([operation, operation, operation]);

    expect(result.values, {'name': 'Food'});
    expect(result.appliedOperationIds, {'op-1'});
  });

  test('conflicting payload for the same op id is rejected', () {
    expect(
      () => engine.merge([
        _op(
          id: 'op-1',
          clock: 1,
          device: 'device-a',
          patch: '{"name":"Food"}',
        ),
        _op(
          id: 'op-1',
          clock: 1,
          device: 'device-a',
          patch: '{"name":"Transport"}',
        ),
      ]),
      throwsA(
        isA<SyncMergeError>().having(
          (error) => error.code,
          'code',
          SyncMergeErrorCode.operationIdCollision,
        ),
      ),
    );
  });

  test('delete blocks older updates in every delivery order', () {
    final update = _op(
      id: 'op-update',
      clock: 4,
      device: 'device-z',
      patch: '{"name":"Old update"}',
    );
    final deletion = _op(
      id: 'op-delete',
      clock: 5,
      device: 'device-a',
      type: SyncMutationType.delete,
      patch: '{}',
    );

    for (final order in _permutations([update, deletion])) {
      final state = engine.merge(order);
      expect(state.isDeleted, isTrue);
      expect(state.values['name'], 'Old update');
    }
  });

  test('newer update may supersede an older tombstone deterministically', () {
    final deletion = _op(
      id: 'op-delete',
      clock: 5,
      device: 'device-z',
      type: SyncMutationType.delete,
      patch: '{}',
    );
    final update = _op(
      id: 'op-update',
      clock: 6,
      device: 'device-a',
      patch: '{"name":"Restored"}',
    );

    for (final order in _permutations([deletion, update])) {
      final state = engine.merge(order);
      expect(state.isDeleted, isFalse);
      expect(state.values['name'], 'Restored');
    }
  });

  test('rejects operations from different entities in one merge', () {
    expect(
      () => engine.merge([
        _op(
          id: 'op-1',
          clock: 1,
          device: 'device-a',
          patch: '{"name":"Food"}',
          entityId: 'category-1',
        ),
        _op(
          id: 'op-2',
          clock: 2,
          device: 'device-a',
          patch: '{"name":"Transport"}',
          entityId: 'category-2',
        ),
      ]),
      throwsA(
        isA<SyncMergeError>().having(
          (error) => error.code,
          'code',
          SyncMergeErrorCode.mixedEntity,
        ),
      ),
    );
  });

  test('same device and Lamport clock cannot identify different operations', () {
    expect(
      () => engine.merge([
        _op(
          id: 'op-name',
          clock: 7,
          device: 'device-a',
          patch: '{"name":"Food"}',
        ),
        _op(
          id: 'op-kind',
          clock: 7,
          device: 'device-a',
          patch: '{"kind":"EXPENSE"}',
        ),
      ]),
      throwsA(
        isA<SyncMergeError>().having(
          (error) => error.code,
          'code',
          SyncMergeErrorCode.versionCollision,
        ),
      ),
    );
  });

  test('delete and update with the same device version are rejected', () {
    expect(
      () => engine.merge([
        _op(
          id: 'op-delete',
          clock: 8,
          device: 'device-a',
          type: SyncMutationType.delete,
          patch: '{}',
        ),
        _op(
          id: 'op-update',
          clock: 8,
          device: 'device-a',
          patch: '{"name":"Impossible"}',
        ),
      ]),
      throwsA(
        isA<SyncMergeError>().having(
          (error) => error.code,
          'code',
          SyncMergeErrorCode.versionCollision,
        ),
      ),
    );
  });

  test('delete/update tie is resolved by device id in every delivery order', () {
    final update = _op(
      id: 'op-update',
      clock: 5,
      device: 'device-a',
      patch: '{"name":"Candidate"}',
    );
    final deletion = _op(
      id: 'op-delete',
      clock: 5,
      device: 'device-b',
      type: SyncMutationType.delete,
      patch: '{}',
    );

    for (final order in _permutations([update, deletion])) {
      final state = engine.merge(order);
      expect(state.isDeleted, isTrue);
      expect(state.tombstoneVersion?.deviceId, 'device-b');
    }
  });

  test('equal field version with different values is rejected', () {
    expect(
      () => engine.merge([
        _op(
          id: 'op-1',
          clock: 2,
          device: 'device-a',
          patch: '{"name":"One"}',
        ),
        _op(
          id: 'op-2',
          clock: 2,
          device: 'device-a',
          patch: '{"name":"Two"}',
        ),
      ]),
      throwsA(
        isA<SyncMergeError>().having(
          (error) => error.code,
          'code',
          SyncMergeErrorCode.versionCollision,
        ),
      ),
    );
  });
}

SignedSyncOperation _op({
  required String id,
  required int clock,
  required String device,
  required String patch,
  SyncMutationType type = SyncMutationType.patch,
  String budgetId = 'budget-1',
  String entityType = 'category',
  String entityId = 'category-1',
}) {
  return SignedSyncOperation(
    operationId: id,
    budgetId: budgetId,
    entityType: entityType,
    entityId: entityId,
    type: type,
    patchJson: patch,
    authorId: 'user-1',
    deviceId: device,
    logicalClock: BigInt.from(clock),
    createdAt: DateTime.utc(2026, 9, 30),
  );
}

List<List<T>> _permutations<T>(List<T> values) {
  if (values.length <= 1) return [List<T>.of(values)];

  final result = <List<T>>[];
  for (var index = 0; index < values.length; index++) {
    final head = values[index];
    final tail = [
      ...values.take(index),
      ...values.skip(index + 1),
    ];
    for (final permutation in _permutations(tail)) {
      result.add([head, ...permutation]);
    }
  }
  return result;
}

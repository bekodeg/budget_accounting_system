import 'package:budget_accounting_system/src/application/errors/sync_protocol_error.dart';
import 'package:budget_accounting_system/src/application/services/sync_protocol_codec.dart';
import 'package:budget_accounting_system/src/domain/models/sync_mutation.dart';
import 'package:budget_accounting_system/src/domain/models/sync_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = SyncProtocolCodec();

  test('round-trips hello, batch, ack and error messages', () {
    final operation = SyncWireOperation(
      operation: SignedSyncOperation(
        operationId: 'op-1',
        budgetId: 'budget-1',
        entityType: 'category',
        entityId: 'category-1',
        type: SyncMutationType.patch,
        patchJson: '{"name":"Food"}',
        authorId: 'user-1',
        deviceId: 'device-a',
        logicalClock: BigInt.from(7),
        createdAt: DateTime.utc(2026, 9, 30, 10),
      ),
      signature: 'c2lnbmF0dXJl',
    );
    final messages = <SyncProtocolMessage>[
      SyncHelloMessage(
        version: SyncProtocolCodec.currentVersion,
        budgetId: 'budget-1',
        deviceId: 'device-a',
        stateVector: SyncStateVector({
          'device-a': BigInt.from(7),
          'device-b': BigInt.from(3),
        }),
      ),
      SyncOperationsBatchMessage(
        version: SyncProtocolCodec.currentVersion,
        budgetId: 'budget-1',
        batchId: 'device-a:1',
        operations: [operation],
        hasMore: false,
      ),
      SyncAckMessage(
        version: SyncProtocolCodec.currentVersion,
        budgetId: 'budget-1',
        batchId: 'device-a:1',
        stateVector: SyncStateVector({'device-a': BigInt.from(7)}),
      ),
      const SyncErrorMessage(
        version: SyncProtocolCodec.currentVersion,
        budgetId: 'budget-1',
        code: 'invalidSignature',
        message: 'bad signature',
      ),
    ];

    final decoded = messages
        .map((message) => codec.decode(codec.encode(message)))
        .toList();

    final hello = decoded[0] as SyncHelloMessage;
    expect(hello.deviceId, 'device-a');
    expect(hello.stateVector.clocks, {
      'device-a': BigInt.from(7),
      'device-b': BigInt.from(3),
    });

    final batch = decoded[1] as SyncOperationsBatchMessage;
    expect(batch.batchId, 'device-a:1');
    expect(batch.operations, [operation]);
    expect(batch.hasMore, isFalse);

    final ack = decoded[2] as SyncAckMessage;
    expect(ack.batchId, 'device-a:1');
    expect(ack.stateVector.clockFor('device-a'), BigInt.from(7));

    final error = decoded[3] as SyncErrorMessage;
    expect(error.code, 'invalidSignature');
    expect(error.message, 'bad signature');
  });

  test('rejects unsupported protocol version explicitly', () {
    expect(
      () => codec.decode(
        '{"v":2,"type":"hello","budget_id":"budget-1",'
                '"device_id":"device-a","state_vector":{}}'
            .codeUnits,
      ),
      throwsA(
        isA<SyncProtocolError>().having(
          (error) => error.code,
          'code',
          SyncProtocolErrorCode.unsupportedVersion,
        ),
      ),
    );
  });

  test('rejects negative state-vector clock', () {
    expect(
      () => codec.decode(
        '{"v":1,"type":"hello","budget_id":"budget-1",'
                '"device_id":"device-a","state_vector":{"device-a":"-1"}}'
            .codeUnits,
      ),
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

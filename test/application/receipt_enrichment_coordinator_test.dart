import 'package:budget_accounting_system/src/application/ports/receipt_enrichment_provider.dart';
import 'package:budget_accounting_system/src/application/services/receipt_enrichment_coordinator.dart';
import 'package:budget_accounting_system/src/domain/models/receipt_qr_draft.dart';
import 'package:budget_accounting_system/src/domain/repositories/receipt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fills only missing fields and keeps local confirmed values', () async {
    final repository = _Repository(
      ReceiptQrDraft(
        receiptId: 'receipt-1',
        budgetId: 'budget-1',
        rawQr: 'qr',
        occurredAt: DateTime(2026, 9, 30),
        totalMinor: BigInt.from(1000),
        description: null,
        parsedPayloadJson: '{}',
        parseStatus: 'PARSED',
        isDuplicate: false,
      ),
    );
    final coordinator = ReceiptEnrichmentCoordinator(
      provider: const _Provider(
        ReceiptEnrichment(
          occurredAt: null,
          totalMinor: null,
          merchant: 'Provider merchant',
          items: ['A', 'B'],
        ),
      ),
      repository: repository,
    );

    await coordinator.enrichInBackground(repository.current);

    expect(repository.current.totalMinor, BigInt.from(1000));
    expect(repository.current.description, 'Provider merchant');
    expect(repository.current.parsedPayloadJson, contains('"provider":"test"'));
    expect(repository.current.parsedPayloadJson, contains('"A"'));
  });

  test('provider network failure is non-blocking and does not mutate receipt', () async {
    final original = ReceiptQrDraft(
      receiptId: 'receipt-1',
      budgetId: 'budget-1',
      rawQr: 'qr',
      occurredAt: null,
      totalMinor: null,
      description: null,
      parsedPayloadJson: '{}',
      parseStatus: 'NEW',
      isDuplicate: false,
    );
    final repository = _Repository(original);
    final coordinator = ReceiptEnrichmentCoordinator(
      provider: const _FailingProvider(),
      repository: repository,
    );

    await coordinator.enrichInBackground(original);

    expect(repository.current.parsedPayloadJson, '{}');
    expect(repository.saves, 0);
  });

  test('provider can be replaced without changing coordinator contract', () async {
    final repository = _Repository(
      ReceiptQrDraft(
        receiptId: 'receipt-1',
        budgetId: 'budget-1',
        rawQr: 'qr',
        occurredAt: null,
        totalMinor: null,
        description: null,
        parsedPayloadJson: '{}',
        parseStatus: 'NEW',
        isDuplicate: false,
      ),
    );

    for (final provider in <ReceiptEnrichmentProvider>[
      const _Provider(ReceiptEnrichment(merchant: 'A')),
      const _SecondProvider(),
    ]) {
      final coordinator = ReceiptEnrichmentCoordinator(
        provider: provider,
        repository: repository,
      );
      await coordinator.enrichInBackground(repository.current);
    }

    expect(repository.current.description, 'A');
  });
}

final class _Repository implements ReceiptRepository {
  _Repository(this.current);

  ReceiptQrDraft current;
  int saves = 0;

  @override
  Future<ReceiptQrDraft?> findById(String receiptId) async =>
      current.receiptId == receiptId ? current : null;

  @override
  Future<ReceiptQrDraft?> findByRawQr({
    required String budgetId,
    required String rawQr,
  }) async => null;

  @override
  Future<void> saveReceipt(ReceiptQrDraft receipt) async {
    current = receipt;
    saves += 1;
  }
}

final class _Provider implements ReceiptEnrichmentProvider {
  const _Provider(this.result);

  final ReceiptEnrichment result;

  @override
  String get providerId => 'test';

  @override
  Future<ReceiptEnrichment?> enrich(ReceiptQrDraft receipt) async => result;
}

final class _SecondProvider implements ReceiptEnrichmentProvider {
  const _SecondProvider();

  @override
  String get providerId => 'second';

  @override
  Future<ReceiptEnrichment?> enrich(ReceiptQrDraft receipt) async {
    return const ReceiptEnrichment(merchant: 'B');
  }
}

final class _FailingProvider implements ReceiptEnrichmentProvider {
  const _FailingProvider();

  @override
  String get providerId => 'failing';

  @override
  Future<ReceiptEnrichment?> enrich(ReceiptQrDraft receipt) {
    throw StateError('network unavailable');
  }
}

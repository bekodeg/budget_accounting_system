import '../../application/ports/receipt_enrichment_provider.dart';
import '../../domain/models/receipt_qr_draft.dart';

final class MockReceiptEnrichmentProvider implements ReceiptEnrichmentProvider {
  const MockReceiptEnrichmentProvider();

  @override
  String get providerId => 'mock';

  @override
  Future<ReceiptEnrichment?> enrich(ReceiptQrDraft receipt) async {
    if (receipt.rawQr.isEmpty) return null;
    return const ReceiptEnrichment(
      merchant: 'Mock merchant',
      items: ['Mock item'],
    );
  }
}

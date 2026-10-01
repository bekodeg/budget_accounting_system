import '../../domain/models/receipt_qr_draft.dart';

final class ReceiptEnrichment {
  const ReceiptEnrichment({
    this.occurredAt,
    this.totalMinor,
    this.merchant,
    this.items = const [],
  });

  final DateTime? occurredAt;
  final BigInt? totalMinor;
  final String? merchant;
  final List<String> items;
}

abstract interface class ReceiptEnrichmentProvider {
  String get providerId;

  Future<ReceiptEnrichment?> enrich(ReceiptQrDraft receipt);
}

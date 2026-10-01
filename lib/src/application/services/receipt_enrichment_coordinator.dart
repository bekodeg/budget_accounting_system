import 'dart:convert';

import '../../domain/models/receipt_qr_draft.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../ports/receipt_enrichment_provider.dart';

final class ReceiptEnrichmentCoordinator {
  const ReceiptEnrichmentCoordinator({
    required ReceiptEnrichmentProvider provider,
    required ReceiptRepository repository,
  }) : _provider = provider,
       _repository = repository;

  final ReceiptEnrichmentProvider _provider;
  final ReceiptRepository _repository;

  Future<void> enrichInBackground(ReceiptQrDraft localReceipt) async {
    try {
      final enriched = await _provider.enrich(localReceipt);
      if (enriched == null) return;

      final latest = await _repository.findById(localReceipt.receiptId);
      if (latest == null) return;

      final payload = _mergePayload(
        latest.parsedPayloadJson,
        providerId: _provider.providerId,
        items: enriched.items,
      );

      final updated = ReceiptQrDraft(
        receiptId: latest.receiptId,
        budgetId: latest.budgetId,
        rawQr: latest.rawQr,
        occurredAt: latest.occurredAt ?? enriched.occurredAt,
        totalMinor: latest.totalMinor ?? enriched.totalMinor,
        description: latest.description ?? enriched.merchant,
        parsedPayloadJson: payload,
        parseStatus: _status(
          latest.occurredAt ?? enriched.occurredAt,
          latest.totalMinor ?? enriched.totalMinor,
          latest.description ?? enriched.merchant,
        ),
        isDuplicate: latest.isDuplicate,
        imagePath: latest.imagePath,
      );
      await _repository.saveReceipt(updated);
    } on Object {
      // Enrichment is best-effort. Local receipt remains authoritative.
    }
  }

  String _mergePayload(
    String current, {
    required String providerId,
    required List<String> items,
  }) {
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(current);
      decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } on Object {
      decoded = <String, dynamic>{};
    }
    decoded['enrichment'] = {'provider': providerId, 'items': items};
    return jsonEncode(decoded);
  }

  String _status(DateTime? date, BigInt? total, String? merchant) {
    if (date != null && total != null) return 'PARSED';
    if (date != null || total != null || merchant != null) return 'PARTIAL';
    return 'NEW';
  }
}

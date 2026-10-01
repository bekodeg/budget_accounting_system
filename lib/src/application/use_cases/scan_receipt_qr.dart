import 'dart:async';

import '../../domain/models/receipt_qr_draft.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../ports/id_generator.dart';
import '../services/fiscal_receipt_qr_parser.dart';
import '../services/receipt_enrichment_coordinator.dart';

final class ScanReceiptQr {
  const ScanReceiptQr({
    required ReceiptRepository receiptRepository,
    required FiscalReceiptQrParser parser,
    required IdGenerator idGenerator,
    required BudgetAuthorizationGuard authorization,
    ReceiptEnrichmentCoordinator? enrichmentCoordinator,
  }) : _receiptRepository = receiptRepository,
       _parser = parser,
       _idGenerator = idGenerator,
       _authorization = authorization,
       _enrichmentCoordinator = enrichmentCoordinator;

  final ReceiptRepository _receiptRepository;
  final FiscalReceiptQrParser _parser;
  final IdGenerator _idGenerator;
  final BudgetAuthorizationGuard _authorization;
  final ReceiptEnrichmentCoordinator? _enrichmentCoordinator;

  Future<ReceiptQrDraft> call({
    required String budgetId,
    required String rawQr,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    final normalized = rawQr.trim();
    if (normalized.isEmpty) {
      throw const FormatException('QR-код пуст.');
    }

    final duplicate = await _receiptRepository.findByRawQr(
      budgetId: budgetId,
      rawQr: normalized,
    );
    if (duplicate != null) return duplicate;

    final parsed = _parser.parse(normalized);
    final draft = ReceiptQrDraft(
      receiptId: _idGenerator.nextId(),
      budgetId: budgetId,
      rawQr: normalized,
      occurredAt: parsed.occurredAt,
      totalMinor: parsed.totalMinor,
      description: parsed.merchant,
      parsedPayloadJson: parsed.parsedPayloadJson,
      parseStatus: parsed.parseStatus,
      isDuplicate: false,
    );
    await _receiptRepository.saveReceipt(draft);
    final enrichment = _enrichmentCoordinator;
    if (enrichment != null) {
      unawaited(enrichment.enrichInBackground(draft));
    }
    return draft;
  }
}

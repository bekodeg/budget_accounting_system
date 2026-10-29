import '../../domain/models/receipt_item.dart';
import '../../domain/models/receipt_qr_draft.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';

final class UpdateReceiptItems {
  const UpdateReceiptItems({
    required ReceiptRepository receiptRepository,
    required BudgetAuthorizationGuard authorization,
  }) : _receiptRepository = receiptRepository,
       _authorization = authorization;

  final ReceiptRepository _receiptRepository;
  final BudgetAuthorizationGuard _authorization;

  Future<ReceiptQrDraft> call({
    required String budgetId,
    required String receiptId,
    required List<ReceiptItem> items,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );
    final latest = await _receiptRepository.findById(receiptId);
    if (latest == null || latest.budgetId != budgetId) {
      throw StateError('Receipt is not available in this budget.');
    }
    for (final item in items) {
      if (item.name.trim().isEmpty ||
          !item.quantity.isFinite ||
          item.quantity <= 0 ||
          (item.unitPriceMinor != null && item.unitPriceMinor! < BigInt.zero) ||
          (item.lineTotalMinor != null && item.lineTotalMinor! < BigInt.zero)) {
        throw FormatException('Invalid receipt item.');
      }
    }
    final updated = ReceiptQrDraft(
      receiptId: latest.receiptId,
      budgetId: latest.budgetId,
      rawQr: latest.rawQr,
      occurredAt: latest.occurredAt,
      totalMinor: latest.totalMinor,
      description: latest.description,
      parsedPayloadJson: receiptPayloadWithItems(
        latest.parsedPayloadJson,
        items,
      ),
      parseStatus: latest.parseStatus,
      isDuplicate: latest.isDuplicate,
      imagePath: latest.imagePath,
    );
    await _receiptRepository.saveReceipt(updated);
    return updated;
  }
}

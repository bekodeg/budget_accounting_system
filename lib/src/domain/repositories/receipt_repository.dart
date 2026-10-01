import '../models/receipt_qr_draft.dart';

abstract interface class ReceiptRepository {
  Future<ReceiptQrDraft?> findById(String receiptId);

  Future<ReceiptQrDraft?> findByRawQr({
    required String budgetId,
    required String rawQr,
  });

  Future<void> saveReceipt(ReceiptQrDraft receipt);
}

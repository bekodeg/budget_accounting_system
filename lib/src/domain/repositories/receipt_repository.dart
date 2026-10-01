import '../models/receipt_qr_draft.dart';

abstract interface class ReceiptRepository {
  Future<ReceiptQrDraft?> findByRawQr({
    required String budgetId,
    required String rawQr,
  });

  Future<void> saveReceipt(ReceiptQrDraft receipt);
}

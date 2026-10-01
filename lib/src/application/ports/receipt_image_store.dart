abstract interface class ReceiptImageStore {
  Future<String> persist({
    required String sourcePath,
    required String receiptId,
  });
}

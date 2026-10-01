final class ReceiptQrDraft {
  const ReceiptQrDraft({
    required this.receiptId,
    required this.rawQr,
    required this.occurredAt,
    required this.totalMinor,
    required this.description,
    required this.parseStatus,
    required this.isDuplicate,
  });

  final String receiptId;
  final String rawQr;
  final DateTime? occurredAt;
  final BigInt? totalMinor;
  final String? description;
  final String parseStatus;
  final bool isDuplicate;
}

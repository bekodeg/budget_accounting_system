import 'package:drift/drift.dart';

import '../../domain/models/receipt_qr_draft.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../dal/plan_receipt_dao.dart';
import '../database/app_database.dart';

final class DriftReceiptRepository implements ReceiptRepository {
  const DriftReceiptRepository(this._dao);

  final PlanReceiptDao _dao;

  @override
  Future<ReceiptQrDraft?> findByRawQr({
    required String budgetId,
    required String rawQr,
  }) async {
    final row = await _dao.findReceiptByRawQr(
      budgetId: budgetId,
      rawQr: rawQr,
    );
    if (row == null) return null;
    return _toDraft(row, isDuplicate: true);
  }

  @override
  Future<void> saveQrReceipt(ReceiptQrDraft receipt) {
    return _dao.upsertReceipt(
      ReceiptsCompanion.insert(
        id: receipt.receiptId,
        budgetId: receipt.budgetId,
        rawQr: Value(receipt.rawQr),
        merchant: Value(receipt.description),
        receiptTime: Value(receipt.occurredAt),
        totalMinor: Value(receipt.totalMinor),
        parsedPayload: Value(receipt.parsedPayloadJson),
        parseStatus: Value(receipt.parseStatus),
      ),
    );
  }

  ReceiptQrDraft _toDraft(Receipt row, {required bool isDuplicate}) {
    return ReceiptQrDraft(
      receiptId: row.id,
      budgetId: row.budgetId,
      rawQr: row.rawQr ?? '',
      occurredAt: row.receiptTime,
      totalMinor: row.totalMinor,
      description: row.merchant,
      parsedPayloadJson: row.parsedPayload ?? '{}',
      parseStatus: row.parseStatus,
      isDuplicate: isDuplicate,
    );
  }
}

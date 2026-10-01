import 'package:budget_accounting_system/src/application/authorization/budget_action.dart';
import 'package:budget_accounting_system/src/application/authorization/budget_authorization_guard.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/services/fiscal_receipt_qr_parser.dart';
import 'package:budget_accounting_system/src/application/use_cases/scan_receipt_qr.dart';
import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/receipt_qr_draft.dart';
import 'package:budget_accounting_system/src/domain/repositories/receipt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first scan saves receipt and duplicate scan reuses it', () async {
    final repository = _ReceiptRepository();
    final useCase = ScanReceiptQr(
      receiptRepository: repository,
      parser: const FiscalReceiptQrParser(),
      idGenerator: _IdGenerator(),
      authorization: const _Authorization(),
    );
    const raw = 't=20260930T1913&s=349.50&fn=123&i=42&fp=777';

    final first = await useCase(budgetId: 'budget-1', rawQr: raw);
    final duplicate = await useCase(budgetId: 'budget-1', rawQr: raw);

    expect(first.isDuplicate, isFalse);
    expect(first.totalMinor, BigInt.from(34950));
    expect(repository.saved, hasLength(1));
    expect(duplicate.receiptId, first.receiptId);
    expect(duplicate.isDuplicate, isTrue);
  });
}

final class _ReceiptRepository implements ReceiptRepository {
  final List<ReceiptQrDraft> saved = [];

  @override
  Future<ReceiptQrDraft?> findById(String receiptId) async {
    for (final item in saved) {
      if (item.receiptId == receiptId) return item;
    }
    return null;
  }

  @override
  Future<ReceiptQrDraft?> findByRawQr({
    required String budgetId,
    required String rawQr,
  }) async {
    for (final item in saved) {
      if (item.budgetId == budgetId && item.rawQr == rawQr) {
        return ReceiptQrDraft(
          receiptId: item.receiptId,
          budgetId: item.budgetId,
          rawQr: item.rawQr,
          occurredAt: item.occurredAt,
          totalMinor: item.totalMinor,
          description: item.description,
          parsedPayloadJson: item.parsedPayloadJson,
          parseStatus: item.parseStatus,
          isDuplicate: true,
        );
      }
    }
    return null;
  }

  @override
  Future<void> saveReceipt(ReceiptQrDraft receipt) async {
    saved.add(receipt);
  }
}

final class _IdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String nextId() => 'receipt-${++_next}';
}

final class _Authorization implements BudgetAuthorizationGuard {
  const _Authorization();

  @override
  Future<BudgetMemberProfile> require({
    required String budgetId,
    required BudgetAction action,
  }) async {
    return BudgetMemberProfile(
      userId: 'user-1',
      name: 'User',
      role: MemberRole.owner,
      joinedAt: DateTime(2026),
      revokedAt: null,
    );
  }
}

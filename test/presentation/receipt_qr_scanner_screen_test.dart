import 'dart:async';

import 'package:budget_accounting_system/src/application/authorization/budget_action.dart';
import 'package:budget_accounting_system/src/application/authorization/budget_authorization_guard.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/services/fiscal_receipt_qr_parser.dart';
import 'package:budget_accounting_system/src/application/use_cases/scan_receipt_qr.dart';
import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/receipt_qr_draft.dart';
import 'package:budget_accounting_system/src/domain/repositories/receipt_repository.dart';
import 'package:budget_accounting_system/src/presentation/screens/receipt_qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mock scan returns parsed receipt draft', (tester) async {
    final scans = StreamController<String>();
    final repository = _ReceiptRepository();
    final useCase = ScanReceiptQr(
      receiptRepository: repository,
      parser: const FiscalReceiptQrParser(),
      idGenerator: const _IdGenerator(),
      authorization: const _Authorization(),
    );
    ReceiptQrDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.push<ReceiptQrDraft>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptQrScannerScreen(
                    scanReceiptQr: useCase,
                    budgetId: 'budget-1',
                    scanCodes: scans.stream,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('receipt-scanner-mock')), findsOneWidget);

    scans.add('t=20260930T1913&s=15.20');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, isNotNull);
    expect(result!.totalMinor, BigInt.from(1520));
    expect(repository.saved, hasLength(1));
    await scans.close();
  });

  testWidgets('duplicate scan warns before returning existing draft', (
    tester,
  ) async {
    final scans = StreamController<String>();
    final repository = _ReceiptRepository();
    final useCase = ScanReceiptQr(
      receiptRepository: repository,
      parser: const FiscalReceiptQrParser(),
      idGenerator: const _IdGenerator(),
      authorization: const _Authorization(),
    );
    const raw = 't=20260930T1913&s=15.20';
    await useCase(budgetId: 'budget-1', rawQr: raw);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptQrScannerScreen(
          scanReceiptQr: useCase,
          budgetId: 'budget-1',
          scanCodes: scans.stream,
        ),
      ),
    );

    scans.add(raw);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('receipt-duplicate-dialog')),
      findsOneWidget,
    );
    expect(repository.saved, hasLength(1));
    await scans.close();
  });
}

final class _ReceiptRepository implements ReceiptRepository {
  final List<ReceiptQrDraft> saved = [];

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
  Future<void> saveQrReceipt(ReceiptQrDraft receipt) async {
    saved.add(receipt);
  }
}

final class _IdGenerator implements IdGenerator {
  const _IdGenerator();

  @override
  String nextId() => 'receipt-1';
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

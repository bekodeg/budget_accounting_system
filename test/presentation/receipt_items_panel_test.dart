import 'package:budget_accounting_system/src/application/use_cases/update_receipt_items.dart';
import 'package:budget_accounting_system/src/domain/models/receipt_qr_draft.dart';
import 'package:budget_accounting_system/src/presentation/screens/receipt_items_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('shows unavailable items and allows manual addition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeReceiptRepository();
    const receipt = ReceiptQrDraft(
      receiptId: 'receipt-1',
      budgetId: 'budget-1',
      rawQr: 'raw',
      occurredAt: null,
      totalMinor: null,
      description: null,
      parsedPayloadJson: '{"source":"qr"}',
      parseStatus: 'NEW',
      isDuplicate: false,
    );
    await repository.saveReceipt(receipt);
    final update = UpdateReceiptItems(
      receiptRepository: repository,
      authorization: FakeBudgetAuthorizationGuard(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptItemsPanel(
              receipt: receipt,
              budgetId: 'budget-1',
              updateItems: update,
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('receipt-items-unavailable')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('add-receipt-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-name')),
      'Milk',
    );
    await tester.enterText(
      find.byKey(const ValueKey('receipt-item-line-total')),
      '3.50',
    );
    await tester.tap(find.byKey(const ValueKey('receipt-item-save')));
    await tester.pumpAndSettle();

    expect(repository.receipts['receipt-1']!.items.single.name, 'Milk');
    expect(find.text('Milk'), findsOneWidget);
    expect(find.byKey(const ValueKey('receipt-items-total')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-receipt-item-0')));
    await tester.pumpAndSettle();
    expect(repository.receipts['receipt-1']!.items, isEmpty);
    expect(
      find.byKey(const ValueKey('receipt-items-unavailable')),
      findsOneWidget,
    );
  });
}

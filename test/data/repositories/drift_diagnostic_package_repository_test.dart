import 'package:budget_accounting_system/src/application/ports/diagnostic_log_store.dart';
import 'package:budget_accounting_system/src/data/database/app_database.dart';
import 'package:budget_accounting_system/src/data/repositories/drift_diagnostic_package_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics exclude financial personal qr and key material', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-secret-id',
            name: 'Alice Secret',
            publicKey: 'PUBLIC-KEY-SHOULD-NOT-EXPORT',
          ),
        );
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget-secret-id',
            name: 'Private Family Budget',
            baseCurrency: 'EUR',
            createdBy: 'user-secret-id',
          ),
        );
    await database
        .into(database.devices)
        .insert(
          DevicesCompanion.insert(
            id: 'device-secret-id',
            userId: 'user-secret-id',
            name: const Value('Alice Phone'),
          ),
        );
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'category-secret-id',
            budgetId: 'budget-secret-id',
            name: 'Sensitive category',
            kind: 'EXPENSE',
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account-secret-id',
            budgetId: 'budget-secret-id',
            name: 'Secret Account',
            currency: 'EUR',
          ),
        );
    await database
        .into(database.receipts)
        .insert(
          ReceiptsCompanion.insert(
            id: 'receipt-secret-id',
            budgetId: 'budget-secret-id',
            rawQr: const Value('SECRET_QR_PAYLOAD_123'),
            merchant: const Value('Secret Merchant'),
            totalMinor: Value(BigInt.from(987654321)),
            parseStatus: const Value('FAILED'),
          ),
        );
    await database
        .into(database.budgetTransactions)
        .insert(
          BudgetTransactionsCompanion.insert(
            id: 'transaction-secret-id',
            budgetId: 'budget-secret-id',
            occurredAt: DateTime.utc(2026, 10, 1),
            amountMinor: BigInt.from(987654321),
            currency: 'EUR',
            type: 'EXPENSE',
            authorId: 'user-secret-id',
            accountId: 'account-secret-id',
            categoryId: const Value('category-secret-id'),
            receiptId: const Value('receipt-secret-id'),
            description: const Value('SECRET_TRANSACTION_DESCRIPTION'),
          ),
        );

    final repository = DriftDiagnosticPackageRepository(
      database: database,
      logStore: const _LogStore(),
    );
    final bundle = await repository.collect();
    final combined = '${bundle.diagnosticsJson}\n${bundle.errorsJsonLines}';

    expect(combined, isNot(contains('987654321')));
    expect(combined, isNot(contains('SECRET_TRANSACTION_DESCRIPTION')));
    expect(combined, isNot(contains('SECRET_QR_PAYLOAD_123')));
    expect(combined, isNot(contains('Alice Secret')));
    expect(combined, isNot(contains('budget-secret-id')));
    expect(combined, isNot(contains('PUBLIC-KEY-SHOULD-NOT-EXPORT')));
    expect(combined, contains('"contains_financial_amounts": false'));
    expect(bundle.preview.budgetCount, 1);
    expect(bundle.preview.failedReceiptCount, 1);
  });
}

final class _LogStore implements DiagnosticLogStore {
  const _LogStore();

  @override
  Future<void> append({required String category, required String code}) async {}

  @override
  Future<List<DiagnosticLogRecord>> readRecent({int limit = 100}) async {
    return [
      DiagnosticLogRecord(
        timestamp: DateTime.utc(2026, 10, 1),
        category: 'sync',
        code: 'TimeoutException',
      ),
    ];
  }
}

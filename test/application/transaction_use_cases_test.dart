import 'package:budget_accounting_system/src/application/errors/transaction_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/create_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/delete_transaction.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_account_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/require_category_in_budget.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_transaction.dart';
import 'package:budget_accounting_system/src/domain/models/budget_account.dart';
import 'package:budget_accounting_system/src/domain/models/budget_category.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/receipt_qr_draft.dart';
import 'package:budget_accounting_system/src/domain/value_objects/currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  final eur = Currency('EUR');

  FakeAccountRepository accounts() => FakeAccountRepository(
    accountsByBudget: {
      'budget-1': [
        BudgetAccount(
          id: 'account-1',
          budgetId: 'budget-1',
          name: 'Карта',
          openingBalanceMinor: BigInt.zero,
          currency: eur,
          isArchived: false,
        ),
      ],
    },
  );

  FakeCategoryRepository categories() => FakeCategoryRepository(
    categoriesByBudget: {
      'budget-1': const [
        BudgetCategory(
          id: 'expense-food',
          budgetId: 'budget-1',
          name: 'Продукты',
          kind: CategoryKind.expense,
          isArchived: false,
        ),
        BudgetCategory(
          id: 'income-salary',
          budgetId: 'budget-1',
          name: 'Зарплата',
          kind: CategoryKind.income,
          isArchived: false,
        ),
      ],
    },
  );

  test('creates expense with current user as author', () async {
    final accountRepository = accounts();
    final categoryRepository = categories();
    final transactionRepository = FakeTransactionRepository();
    final useCase = CreateTransaction(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      requireCategoryInBudget: RequireCategoryInBudget(categoryRepository),
      idGenerator: FakeIdGenerator(['transaction-1']),
      authorization: FakeBudgetAuthorizationGuard(),
    );

    final transaction = await useCase(
      budgetId: 'budget-1',
      authorId: 'user-1',
      occurredAt: DateTime(2026, 9, 24, 10),
      amountMinor: BigInt.from(1250),
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'expense-food',
      description: '  Завтрак  ',
    );

    expect(transaction.id, 'transaction-1');
    expect(transaction.authorId, 'user-1');
    expect(transaction.description, 'Завтрак');
    expect(transaction.amount.minorUnits, BigInt.from(1250));
    expect(transactionRepository.snapshot('budget-1'), [transaction]);
  });

  test('links same-budget receipt and preserves link on edit', () async {
    final transactionRepository = FakeTransactionRepository();
    final receipts = FakeReceiptRepository();
    await receipts.saveReceipt(
      const ReceiptQrDraft(
        receiptId: 'receipt-1',
        budgetId: 'budget-1',
        rawQr: 'raw',
        occurredAt: null,
        totalMinor: null,
        description: null,
        parsedPayloadJson: '{}',
        parseStatus: 'NEW',
        isDuplicate: false,
      ),
    );
    await receipts.saveReceipt(
      const ReceiptQrDraft(
        receiptId: 'other-budget-receipt',
        budgetId: 'budget-2',
        rawQr: 'other',
        occurredAt: null,
        totalMinor: null,
        description: null,
        parsedPayloadJson: '{}',
        parseStatus: 'NEW',
        isDuplicate: false,
      ),
    );
    final create = CreateTransaction(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accounts()),
      requireCategoryInBudget: RequireCategoryInBudget(categories()),
      idGenerator: FakeIdGenerator(['transaction-1']),
      authorization: FakeBudgetAuthorizationGuard(),
      receiptRepository: receipts,
    );
    final created = await create(
      budgetId: 'budget-1',
      authorId: 'user-1',
      occurredAt: DateTime(2026, 9, 24),
      amountMinor: BigInt.from(1000),
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'expense-food',
      receiptId: 'receipt-1',
    );
    final update = UpdateTransaction(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accounts()),
      requireCategoryInBudget: RequireCategoryInBudget(categories()),
      authorization: FakeBudgetAuthorizationGuard(),
    );
    final edited = await update(
      budgetId: 'budget-1',
      transactionId: created.id,
      occurredAt: created.occurredAt,
      amountMinor: BigInt.from(1100),
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'expense-food',
    );
    expect(created.receiptId, 'receipt-1');
    expect(edited.receiptId, 'receipt-1');
    expect(
      transactionRepository.snapshot('budget-1').single.receiptId,
      'receipt-1',
    );

    await expectLater(
      create(
        budgetId: 'budget-1',
        authorId: 'user-1',
        occurredAt: DateTime(2026, 9, 24),
        amountMinor: BigInt.from(100),
        type: TransactionType.expense,
        accountId: 'account-1',
        categoryId: 'expense-food',
        receiptId: 'missing',
      ),
      throwsA(
        isA<TransactionError>().having(
          (error) => error.code,
          'code',
          TransactionErrorCode.invalidReceipt,
        ),
      ),
    );
    await expectLater(
      create(
        budgetId: 'budget-1',
        authorId: 'user-1',
        occurredAt: DateTime(2026, 9, 24),
        amountMinor: BigInt.from(100),
        type: TransactionType.expense,
        accountId: 'account-1',
        categoryId: 'expense-food',
        receiptId: 'other-budget-receipt',
      ),
      throwsA(
        isA<TransactionError>().having(
          (error) => error.code,
          'code',
          TransactionErrorCode.invalidReceipt,
        ),
      ),
    );
  });

  test('rejects category incompatible with transaction type', () async {
    final accountRepository = accounts();
    final categoryRepository = categories();
    final useCase = CreateTransaction(
      transactionRepository: FakeTransactionRepository(),
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      requireCategoryInBudget: RequireCategoryInBudget(categoryRepository),
      idGenerator: FakeIdGenerator(['transaction-1']),
      authorization: FakeBudgetAuthorizationGuard(),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        authorId: 'user-1',
        occurredAt: DateTime(2026, 9, 24),
        amountMinor: BigInt.from(100),
        type: TransactionType.income,
        accountId: 'account-1',
        categoryId: 'expense-food',
      ),
      throwsA(
        isA<TransactionError>().having(
          (error) => error.code,
          'code',
          TransactionErrorCode.invalidCategory,
        ),
      ),
    );
  });

  test('update preserves original author and changes updated data', () async {
    final accountRepository = accounts();
    final categoryRepository = categories();
    final transactionRepository = FakeTransactionRepository();
    final create = CreateTransaction(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      requireCategoryInBudget: RequireCategoryInBudget(categoryRepository),
      idGenerator: FakeIdGenerator(['transaction-1']),
      authorization: FakeBudgetAuthorizationGuard(),
    );
    final update = UpdateTransaction(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      requireCategoryInBudget: RequireCategoryInBudget(categoryRepository),
      authorization: FakeBudgetAuthorizationGuard(),
    );

    final created = await create(
      budgetId: 'budget-1',
      authorId: 'user-1',
      occurredAt: DateTime(2026, 9, 24),
      amountMinor: BigInt.from(1000),
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'expense-food',
    );

    final updated = await update(
      budgetId: 'budget-1',
      transactionId: created.id,
      occurredAt: DateTime(2026, 9, 23),
      amountMinor: BigInt.from(2500),
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'expense-food',
      description: 'Магазин',
    );

    expect(updated.authorId, 'user-1');
    expect(updated.amount.minorUnits, BigInt.from(2500));
    expect(updated.description, 'Магазин');
    expect(
      updated.updatedAt.isAfter(created.updatedAt) ||
          updated.updatedAt.isAtSameMomentAs(created.updatedAt),
      isTrue,
    );
  });

  test('soft delete removes transaction from active stream', () async {
    final accountRepository = accounts();
    final categoryRepository = categories();
    final transactionRepository = FakeTransactionRepository();
    final create = CreateTransaction(
      transactionRepository: transactionRepository,
      requireAccountInBudget: RequireAccountInBudget(accountRepository),
      requireCategoryInBudget: RequireCategoryInBudget(categoryRepository),
      idGenerator: FakeIdGenerator(['transaction-1']),
      authorization: FakeBudgetAuthorizationGuard(),
    );
    final delete = DeleteTransaction(
      repository: transactionRepository,
      authorization: FakeBudgetAuthorizationGuard(),
    );

    final created = await create(
      budgetId: 'budget-1',
      authorId: 'user-1',
      occurredAt: DateTime(2026, 9, 24),
      amountMinor: BigInt.from(1000),
      type: TransactionType.expense,
      accountId: 'account-1',
      categoryId: 'expense-food',
    );

    await delete(budgetId: 'budget-1', transactionId: created.id);

    expect(transactionRepository.snapshot('budget-1'), isEmpty);
  });
}

import 'package:budget_accounting_system/src/application/authorization/budget_action.dart';
import 'package:budget_accounting_system/src/application/authorization/budget_authorization_guard.dart';
import 'package:budget_accounting_system/src/application/ports/id_generator.dart';
import 'package:budget_accounting_system/src/application/ports/receipt_image_store.dart';
import 'package:budget_accounting_system/src/application/ports/receipt_photo_analyzer.dart';
import 'package:budget_accounting_system/src/application/services/fiscal_receipt_qr_parser.dart';
import 'package:budget_accounting_system/src/application/services/receipt_ocr_parser.dart';
import 'package:budget_accounting_system/src/application/use_cases/import_receipt_photo.dart';
import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/domain/models/receipt_qr_draft.dart';
import 'package:budget_accounting_system/src/domain/repositories/receipt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists image before OCR and saves parsed receipt', () async {
    final repository = _Repository();
    final store = _ImageStore();
    final useCase = ImportReceiptPhoto(
      receiptRepository: repository,
      imageStore: store,
      analyzer: const _Analyzer(
        ReceiptPhotoAnalysis(
          qrRawValue: null,
          recognizedText: 'Market\n30.09.2026\nTOTAL 15.20',
        ),
      ),
      qrParser: const FiscalReceiptQrParser(),
      ocrParser: const ReceiptOcrParser(),
      idGenerator: const _Ids(),
      authorization: const _Authorization(),
    );

    final result = await useCase(
      budgetId: 'budget-1',
      sourcePath: '/incoming/photo.jpg',
    );

    expect(store.calls, ['/incoming/photo.jpg']);
    expect(result.imagePath, '/safe/receipt-1.jpg');
    expect(result.totalMinor, BigInt.from(1520));
    expect(result.parseStatus, 'PARSED');
    expect(repository.saved, hasLength(1));
  });

  test('recognition failure still saves original image and failed receipt', () async {
    final repository = _Repository();
    final useCase = ImportReceiptPhoto(
      receiptRepository: repository,
      imageStore: _ImageStore(),
      analyzer: const _FailingAnalyzer(),
      qrParser: const FiscalReceiptQrParser(),
      ocrParser: const ReceiptOcrParser(),
      idGenerator: const _Ids(),
      authorization: const _Authorization(),
    );

    final result = await useCase(
      budgetId: 'budget-1',
      sourcePath: '/incoming/photo.jpg',
    );

    expect(result.parseStatus, 'FAILED');
    expect(result.imagePath, '/safe/receipt-1.jpg');
    expect(repository.saved.single.imagePath, isNotNull);
  });

  test('QR on photo is preferred over OCR', () async {
    final repository = _Repository();
    final useCase = ImportReceiptPhoto(
      receiptRepository: repository,
      imageStore: _ImageStore(),
      analyzer: const _Analyzer(
        ReceiptPhotoAnalysis(
          qrRawValue: 't=20260930T1215&s=9.99',
          recognizedText: 'TOTAL 100.00',
        ),
      ),
      qrParser: const FiscalReceiptQrParser(),
      ocrParser: const ReceiptOcrParser(),
      idGenerator: const _Ids(),
      authorization: const _Authorization(),
    );

    final result = await useCase(
      budgetId: 'budget-1',
      sourcePath: '/incoming/photo.jpg',
    );

    expect(result.totalMinor, BigInt.from(999));
    expect(result.rawQr, isNotEmpty);
  });
}

final class _Repository implements ReceiptRepository {
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
  }) async => null;

  @override
  Future<void> saveReceipt(ReceiptQrDraft receipt) async {
    saved.add(receipt);
  }
}

final class _ImageStore implements ReceiptImageStore {
  final List<String> calls = [];

  @override
  Future<String> persist({
    required String sourcePath,
    required String receiptId,
  }) async {
    calls.add(sourcePath);
    return '/safe/$receiptId.jpg';
  }
}

final class _Analyzer implements ReceiptPhotoAnalyzer {
  const _Analyzer(this.result);
  final ReceiptPhotoAnalysis result;

  @override
  Future<ReceiptPhotoAnalysis> analyze(String imagePath) async => result;
}

final class _FailingAnalyzer implements ReceiptPhotoAnalyzer {
  const _FailingAnalyzer();

  @override
  Future<ReceiptPhotoAnalysis> analyze(String imagePath) {
    throw StateError('ocr failed');
  }
}

final class _Ids implements IdGenerator {
  const _Ids();

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

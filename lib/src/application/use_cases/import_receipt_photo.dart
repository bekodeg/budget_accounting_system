import '../../domain/models/receipt_qr_draft.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../authorization/budget_action.dart';
import '../authorization/budget_authorization_guard.dart';
import '../ports/id_generator.dart';
import '../ports/receipt_image_store.dart';
import '../ports/receipt_photo_analyzer.dart';
import '../services/fiscal_receipt_qr_parser.dart';
import '../services/receipt_ocr_parser.dart';

final class ImportReceiptPhoto {
  const ImportReceiptPhoto({
    required ReceiptRepository receiptRepository,
    required ReceiptImageStore imageStore,
    required ReceiptPhotoAnalyzer analyzer,
    required FiscalReceiptQrParser qrParser,
    required ReceiptOcrParser ocrParser,
    required IdGenerator idGenerator,
    required BudgetAuthorizationGuard authorization,
  }) : _receiptRepository = receiptRepository,
       _imageStore = imageStore,
       _analyzer = analyzer,
       _qrParser = qrParser,
       _ocrParser = ocrParser,
       _idGenerator = idGenerator,
       _authorization = authorization;

  final ReceiptRepository _receiptRepository;
  final ReceiptImageStore _imageStore;
  final ReceiptPhotoAnalyzer _analyzer;
  final FiscalReceiptQrParser _qrParser;
  final ReceiptOcrParser _ocrParser;
  final IdGenerator _idGenerator;
  final BudgetAuthorizationGuard _authorization;

  Future<ReceiptQrDraft> call({
    required String budgetId,
    required String sourcePath,
  }) async {
    await _authorization.require(
      budgetId: budgetId,
      action: BudgetAction.mutate,
    );

    final receiptId = _idGenerator.nextId();
    final imagePath = await _imageStore.persist(
      sourcePath: sourcePath,
      receiptId: receiptId,
    );

    try {
      final analysis = await _analyzer.analyze(imagePath);
      final qr = analysis.qrRawValue?.trim();
      if (qr != null && qr.isNotEmpty) {
        final existing = await _receiptRepository.findByRawQr(
          budgetId: budgetId,
          rawQr: qr,
        );
        if (existing != null) {
          final updated = ReceiptQrDraft(
            receiptId: existing.receiptId,
            budgetId: existing.budgetId,
            rawQr: existing.rawQr,
            occurredAt: existing.occurredAt,
            totalMinor: existing.totalMinor,
            description: existing.description,
            parsedPayloadJson: existing.parsedPayloadJson,
            parseStatus: existing.parseStatus,
            isDuplicate: true,
            imagePath: imagePath,
          );
          await _receiptRepository.saveReceipt(updated);
          return updated;
        }

        final parsed = _qrParser.parse(qr);
        final draft = ReceiptQrDraft(
          receiptId: receiptId,
          budgetId: budgetId,
          rawQr: qr,
          occurredAt: parsed.occurredAt,
          totalMinor: parsed.totalMinor,
          description: parsed.merchant,
          parsedPayloadJson: parsed.parsedPayloadJson,
          parseStatus: parsed.parseStatus,
          isDuplicate: false,
          imagePath: imagePath,
        );
        await _receiptRepository.saveReceipt(draft);
        return draft;
      }

      final parsed = _ocrParser.parse(analysis.recognizedText);
      final draft = ReceiptQrDraft(
        receiptId: receiptId,
        budgetId: budgetId,
        rawQr: '',
        occurredAt: parsed.occurredAt,
        totalMinor: parsed.totalMinor,
        description: parsed.merchant,
        parsedPayloadJson: parsed.parsedPayloadJson,
        parseStatus: parsed.parseStatus,
        isDuplicate: false,
        imagePath: imagePath,
      );
      await _receiptRepository.saveReceipt(draft);
      return draft;
    } on Object {
      final failed = ReceiptQrDraft(
        receiptId: receiptId,
        budgetId: budgetId,
        rawQr: '',
        occurredAt: null,
        totalMinor: null,
        description: null,
        parsedPayloadJson: '{"source":"photo","error":"recognition_failed"}',
        parseStatus: 'FAILED',
        isDuplicate: false,
        imagePath: imagePath,
      );
      await _receiptRepository.saveReceipt(failed);
      return failed;
    }
  }
}

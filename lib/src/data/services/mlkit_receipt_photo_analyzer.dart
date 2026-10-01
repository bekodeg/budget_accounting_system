import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as barcode;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as text;

import '../../application/ports/receipt_photo_analyzer.dart';

final class MlKitReceiptPhotoAnalyzer implements ReceiptPhotoAnalyzer {
  const MlKitReceiptPhotoAnalyzer();

  @override
  Future<ReceiptPhotoAnalysis> analyze(String imagePath) async {
    final barcodeScanner = barcode.BarcodeScanner(
      formats: [barcode.BarcodeFormat.qrCode],
    );
    try {
      final input = barcode.InputImage.fromFilePath(imagePath);
      final codes = await barcodeScanner.processImage(input);
      for (final code in codes) {
        final raw = code.rawValue?.trim();
        if (raw != null && raw.isNotEmpty) {
          return ReceiptPhotoAnalysis(qrRawValue: raw, recognizedText: '');
        }
      }
    } finally {
      await barcodeScanner.close();
    }

    final recognizer = text.TextRecognizer(
      script: text.TextRecognitionScript.latin,
    );
    try {
      final input = text.InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(input);
      return ReceiptPhotoAnalysis(
        qrRawValue: null,
        recognizedText: recognized.text,
      );
    } finally {
      await recognizer.close();
    }
  }
}

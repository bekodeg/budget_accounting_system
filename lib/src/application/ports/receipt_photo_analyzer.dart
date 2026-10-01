final class ReceiptPhotoAnalysis {
  const ReceiptPhotoAnalysis({
    required this.qrRawValue,
    required this.recognizedText,
  });

  final String? qrRawValue;
  final String recognizedText;
}

abstract interface class ReceiptPhotoAnalyzer {
  Future<ReceiptPhotoAnalysis> analyze(String imagePath);
}

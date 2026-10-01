import 'dart:typed_data';

abstract interface class DiagnosticShareGateway {
  Future<void> share({
    required String fileName,
    required Uint8List zipBytes,
  });
}

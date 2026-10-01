import '../../domain/models/diagnostic_package.dart';

final class DiagnosticPackageBundle {
  const DiagnosticPackageBundle({
    required this.preview,
    required this.diagnosticsJson,
    required this.errorsJsonLines,
  });

  final DiagnosticPackagePreview preview;
  final String diagnosticsJson;
  final String errorsJsonLines;
}

abstract interface class DiagnosticPackageRepository {
  Future<DiagnosticPackageBundle> collect();
}

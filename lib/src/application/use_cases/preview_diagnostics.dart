import '../../domain/models/diagnostic_package.dart';
import '../ports/diagnostic_package_repository.dart';

final class PreviewDiagnostics {
  const PreviewDiagnostics(this._repository);

  final DiagnosticPackageRepository _repository;

  Future<DiagnosticPackagePreview> call() async {
    final bundle = await _repository.collect();
    return bundle.preview;
  }
}

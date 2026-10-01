import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../ports/diagnostic_package_repository.dart';
import '../ports/diagnostic_share_gateway.dart';

final class ExportDiagnostics {
  const ExportDiagnostics({
    required DiagnosticPackageRepository repository,
    required DiagnosticShareGateway shareGateway,
  }) : _repository = repository,
       _shareGateway = shareGateway;

  final DiagnosticPackageRepository _repository;
  final DiagnosticShareGateway _shareGateway;

  Future<void> call() async {
    final bundle = await _repository.collect();
    final archive = Archive()
      ..addFile(ArchiveFile.string('diagnostics.json', bundle.diagnosticsJson))
      ..addFile(ArchiveFile.string('errors.jsonl', bundle.errorsJsonLines));
    final encoded = ZipEncoder().encodeBytes(archive);
    await _shareGateway.share(
      fileName: 'budget-accounting-diagnostics.zip',
      zipBytes: Uint8List.fromList(encoded),
    );
  }
}

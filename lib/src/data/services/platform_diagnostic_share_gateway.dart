import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/ports/diagnostic_share_gateway.dart';

final class PlatformDiagnosticShareGateway implements DiagnosticShareGateway {
  const PlatformDiagnosticShareGateway();

  @override
  Future<void> share({
    required String fileName,
    required Uint8List zipBytes,
  }) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}diagnostic_export',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(zipBytes, flush: true);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'Budget Accounting diagnostics',
        ),
      );
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }
}

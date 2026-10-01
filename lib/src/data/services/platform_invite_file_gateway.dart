import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/ports/invite_file_gateway.dart';

final class PlatformInviteFileGateway implements InviteFileGateway {
  const PlatformInviteFileGateway();

  @override
  Future<void> share({
    required String fileName,
    required String payload,
  }) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}budget_invites',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);

    final safeName = fileName.endsWith('.budgetinvite')
        ? fileName
        : '$fileName.budgetinvite';
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(payload, encoding: utf8, flush: true);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'application/vnd.budget-accounting.invite',
            ),
          ],
          subject: 'Budget invitation',
        ),
      );
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  @override
  Future<String?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['budgetinvite'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return utf8.decode(bytes);
  }
}

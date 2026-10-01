import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/ports/budget_backup_file_gateway.dart';

final class PlatformBudgetBackupFileGateway
    implements BudgetBackupFileGateway {
  const PlatformBudgetBackupFileGateway();

  @override
  Future<void> share({
    required String fileName,
    required String payload,
  }) async {
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}budget_backups',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);

    final safeName = fileName.endsWith('.budgetbackup')
        ? fileName
        : '$fileName.budgetbackup';
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(payload, encoding: utf8, flush: true);

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'application/vnd.budget-accounting.backup',
            ),
          ],
          subject: 'Encrypted budget backup',
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
      allowedExtensions: const ['budgetbackup'],
    );
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }
}

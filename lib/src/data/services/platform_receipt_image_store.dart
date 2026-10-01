import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/ports/receipt_image_store.dart';

final class PlatformReceiptImageStore implements ReceiptImageStore {
  const PlatformReceiptImageStore();

  @override
  Future<String> persist({
    required String sourcePath,
    required String receiptId,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('Receipt image does not exist.');
    }
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}receipts',
    );
    await directory.create(recursive: true);
    final extension = _extension(sourcePath);
    final target = File(
      '${directory.path}${Platform.pathSeparator}$receiptId$extension',
    );
    await source.copy(target.path);
    return target.path;
  }

  String _extension(String path) {
    final index = path.lastIndexOf('.');
    if (index < 0 || index < path.lastIndexOf(Platform.pathSeparator)) {
      return '.jpg';
    }
    final value = path.substring(index).toLowerCase();
    return value.length <= 6 ? value : '.jpg';
  }
}

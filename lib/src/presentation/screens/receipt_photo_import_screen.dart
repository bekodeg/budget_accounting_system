import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/use_cases/import_receipt_photo.dart';
import '../../domain/models/receipt_qr_draft.dart';

final class ReceiptPhotoImportScreen extends StatefulWidget {
  const ReceiptPhotoImportScreen({
    required this.importReceiptPhoto,
    required this.budgetId,
    this.imagePicker,
    super.key,
  });

  final ImportReceiptPhoto importReceiptPhoto;
  final String budgetId;
  final ImagePicker? imagePicker;

  @override
  State<ReceiptPhotoImportScreen> createState() =>
      _ReceiptPhotoImportScreenState();
}

final class _ReceiptPhotoImportScreenState
    extends State<ReceiptPhotoImportScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_processing) return;
    final picker = widget.imagePicker ?? ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (image == null || !mounted) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final draft = await widget.importReceiptPhoto(
        budgetId: widget.budgetId,
        sourcePath: image.path,
      );
      if (!mounted) return;
      Navigator.pop<ReceiptQrDraft>(context, draft);
    } on Object {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Не удалось импортировать фотографию чека.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Фото чека')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Фото сохраняется локально. Сначала приложение ищет QR, '
              'а если его нет — запускает OCR на устройстве.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('receipt-photo-camera'),
              onPressed: _processing ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Снять чек'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('receipt-photo-gallery'),
              onPressed: _processing ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Выбрать из галереи'),
            ),
            if (_processing) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(
                key: ValueKey('receipt-photo-progress'),
              ),
              const SizedBox(height: 8),
              const Text('Распознавание выполняется локально…'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const ValueKey('receipt-photo-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

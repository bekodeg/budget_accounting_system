import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../application/use_cases/scan_receipt_qr.dart';
import '../../domain/models/receipt_qr_draft.dart';

final class ReceiptQrScannerScreen extends StatefulWidget {
  const ReceiptQrScannerScreen({
    required this.scanReceiptQr,
    required this.budgetId,
    this.scanCodes,
    super.key,
  });

  final ScanReceiptQr scanReceiptQr;
  final String budgetId;
  final Stream<String>? scanCodes;

  @override
  State<ReceiptQrScannerScreen> createState() => _ReceiptQrScannerScreenState();
}

final class _ReceiptQrScannerScreenState extends State<ReceiptQrScannerScreen> {
  StreamSubscription<String>? _subscription;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final scanCodes = widget.scanCodes;
    if (scanCodes != null) {
      _subscription = scanCodes.listen(_handleRawQr);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleRawQr(String rawQr) async {
    if (_processing || !mounted) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final draft = await widget.scanReceiptQr(
        budgetId: widget.budgetId,
        rawQr: rawQr,
      );
      if (!mounted) return;

      if (draft.isDuplicate) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('receipt-duplicate-dialog'),
            title: const Text('Чек уже сканировался'),
            content: const Text(
              'Для этого QR уже существует сохраненный чек. '
              'Можно открыть его данные как черновик без создания дубликата.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                key: const ValueKey('receipt-duplicate-continue'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Продолжить'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) {
          setState(() => _processing = false);
          return;
        }
      }

      Navigator.pop<ReceiptQrDraft>(context, draft);
    } on FormatException catch (error) {
      _showError(error.message);
    } on Object {
      _showError('Не удалось обработать QR-код чека.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _error = message;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) continue;
      unawaited(_handleRawQr(rawValue));
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканировать чек')),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.scanCodes == null
                ? MobileScanner(onDetect: _onDetect)
                : const ColoredBox(
                    key: ValueKey('receipt-scanner-mock'),
                    color: Colors.black12,
                    child: Center(child: Text('Тестовый поток QR')),
                  ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Наведите камеру на QR-код фискального чека. '
                      'Распознанные данные откроются как черновик операции.',
                      textAlign: TextAlign.center,
                    ),
                    if (_processing) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        key: ValueKey('receipt-scan-progress'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const ValueKey('receipt-scan-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

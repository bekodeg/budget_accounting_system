import 'dart:convert';

import '../../domain/models/receipt_item.dart';

final class ParsedReceiptOcr {
  const ParsedReceiptOcr({
    required this.occurredAt,
    required this.totalMinor,
    required this.merchant,
    required this.parseStatus,
    required this.parsedPayloadJson,
    required this.items,
  });

  final DateTime? occurredAt;
  final BigInt? totalMinor;
  final String? merchant;
  final String parseStatus;
  final String parsedPayloadJson;
  final List<ReceiptItem> items;
}

final class ReceiptOcrParser {
  const ReceiptOcrParser();

  ParsedReceiptOcr parse(String text) {
    final normalized = text.replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final occurredAt = _findDate(normalized);
    final totalMinor = _findTotal(lines);
    final merchant = lines.isEmpty ? null : lines.first;
    final items = _findItems(lines);

    final recognized =
        occurredAt != null || totalMinor != null || merchant != null;
    final complete = occurredAt != null && totalMinor != null;

    return ParsedReceiptOcr(
      occurredAt: occurredAt,
      totalMinor: totalMinor,
      merchant: merchant,
      parseStatus: complete
          ? 'PARSED'
          : recognized
          ? 'PARTIAL'
          : 'FAILED',
      parsedPayloadJson: jsonEncode({
        'source': 'ocr',
        'text': normalized,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      }),
      items: items,
    );
  }

  List<ReceiptItem> _findItems(List<String> lines) {
    final items = <ReceiptItem>[];
    final detailed = RegExp(
      r'^(.+?)\s+(\d+(?:[.,]\d{1,3})?)\s*[xх×*]\s*(\d+[.,]\d{2})\s+(\d+[.,]\d{2})$',
      caseSensitive: false,
    );
    final simple = RegExp(r'^(.+?)\s+(\d+[.,]\d{2})$');
    final excluded = RegExp(
      r'(итого|total|sum|сумма|оплата|payment|cash|карта|наличн|ндс|vat|скидка|discount|сдача|change)',
      caseSensitive: false,
    );
    // The Latin recognizer can read Cyrillic ИТОГ as WTOT on fiscal receipts.
    final misreadTotal = RegExp(
      r'^[wиi][тt][оo0][гgtт](?:\s|[:=]|$)',
      caseSensitive: false,
    );
    for (final line in lines.skip(1)) {
      if (excluded.hasMatch(line) || misreadTotal.hasMatch(line)) continue;
      final detail = detailed.firstMatch(line);
      if (detail != null) {
        final name = detail.group(1)!.trim();
        final quantity = double.tryParse(detail.group(2)!.replaceAll(',', '.'));
        final unit = _amountMinor(detail.group(3)!);
        final total = _amountMinor(detail.group(4)!);
        if (_validItemName(name) &&
            quantity != null &&
            quantity > 0 &&
            unit != null &&
            total != null) {
          items.add(
            ReceiptItem(
              name: name,
              quantity: quantity,
              unitPriceMinor: unit,
              lineTotalMinor: total,
              source: 'ocr',
            ),
          );
        }
        continue;
      }
      final match = simple.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!.trim();
      final total = _amountMinor(match.group(2)!);
      if (_validItemName(name) && total != null) {
        items.add(
          ReceiptItem(
            name: name,
            quantity: 1,
            unitPriceMinor: total,
            lineTotalMinor: total,
            source: 'ocr',
          ),
        );
      }
    }
    return items;
  }

  bool _validItemName(String name) {
    // OCR may merge the VAT, unit-price and quantity columns into the name.
    // Such a line needs manual review instead of becoming a misleading item.
    final mergedTaxColumns = RegExp(
      r'(?:^|\s)[hнn]?\s*\d{1,2}%\s+\d+[.,]\d{2}\s+\d+\s*$',
      caseSensitive: false,
    );
    return name.length >= 2 &&
        RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(name) &&
        !mergedTaxColumns.hasMatch(name);
  }

  BigInt? _amountMinor(String raw) {
    final parts = raw.replaceAll(',', '.').split('.');
    if (parts.length != 2 || parts[1].length != 2) return null;
    final whole = BigInt.tryParse(parts[0]);
    final fraction = BigInt.tryParse(parts[1]);
    if (whole == null || fraction == null) return null;
    return whole * BigInt.from(100) + fraction;
  }

  DateTime? _findDate(String text) {
    final match = RegExp(
      r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?',
    ).firstMatch(text);
    if (match == null) return null;
    final yearRaw = int.parse(match.group(3)!);
    final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
    try {
      return DateTime(
        year,
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
        int.tryParse(match.group(4) ?? '') ?? 0,
        int.tryParse(match.group(5) ?? '') ?? 0,
      );
    } on Object {
      return null;
    }
  }

  BigInt? _findTotal(List<String> lines) {
    final preferred = lines.where(
      (line) => RegExp(
        r'(итого|total|sum|сумма)',
        caseSensitive: false,
      ).hasMatch(line),
    );
    for (final line in [...preferred, ...lines.reversed]) {
      final matches = RegExp(r'(\d+[.,]\d{2})').allMatches(line).toList();
      if (matches.isEmpty) continue;
      final raw = matches.last.group(1)!.replaceAll(',', '.');
      final parts = raw.split('.');
      return BigInt.parse(parts[0]) * BigInt.from(100) + BigInt.parse(parts[1]);
    }
    return null;
  }
}

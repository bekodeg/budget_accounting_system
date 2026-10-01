import 'dart:convert';

final class ParsedReceiptOcr {
  const ParsedReceiptOcr({
    required this.occurredAt,
    required this.totalMinor,
    required this.merchant,
    required this.parseStatus,
    required this.parsedPayloadJson,
  });

  final DateTime? occurredAt;
  final BigInt? totalMinor;
  final String? merchant;
  final String parseStatus;
  final String parsedPayloadJson;
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

    final recognized =
        occurredAt != null || totalMinor != null || merchant != null;
    final complete = occurredAt != null && totalMinor != null;

    return ParsedReceiptOcr(
      occurredAt: occurredAt,
      totalMinor: totalMinor,
      merchant: merchant,
      parseStatus: complete ? 'PARSED' : recognized ? 'PARTIAL' : 'FAILED',
      parsedPayloadJson: jsonEncode({
        'source': 'ocr',
        'text': normalized,
      }),
    );
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
      return BigInt.parse(parts[0]) * BigInt.from(100) +
          BigInt.parse(parts[1]);
    }
    return null;
  }
}

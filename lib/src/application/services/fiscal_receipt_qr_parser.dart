import 'dart:convert';

final class ParsedFiscalReceiptQr {
  const ParsedFiscalReceiptQr({
    required this.rawQr,
    required this.occurredAt,
    required this.totalMinor,
    required this.merchant,
    required this.parseStatus,
    required this.parsedPayloadJson,
  });

  final String rawQr;
  final DateTime? occurredAt;
  final BigInt? totalMinor;
  final String? merchant;
  final String parseStatus;
  final String parsedPayloadJson;
}

final class FiscalReceiptQrParser {
  const FiscalReceiptQrParser();

  ParsedFiscalReceiptQr parse(String rawQr) {
    final normalized = rawQr.trim();
    final fields = <String, String>{};

    for (final part in normalized.split('&')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = Uri.decodeQueryComponent(part.substring(0, index)).toLowerCase();
      final value = Uri.decodeQueryComponent(part.substring(index + 1));
      if (value.isNotEmpty) fields[key] = value;
    }

    final occurredAt = _parseDate(fields['t']);
    final totalMinor = _parseAmount(fields['s']);
    final merchant = _firstNonEmpty([
      fields['merchant'],
      fields['seller'],
      fields['shop'],
      fields['m'],
    ]);

    final recognized = occurredAt != null || totalMinor != null || merchant != null;
    final complete = occurredAt != null && totalMinor != null;

    return ParsedFiscalReceiptQr(
      rawQr: normalized,
      occurredAt: occurredAt,
      totalMinor: totalMinor,
      merchant: merchant,
      parseStatus: complete ? 'PARSED' : recognized ? 'PARTIAL' : 'NEW',
      parsedPayloadJson: jsonEncode({
        'fields': fields,
        'recognized': recognized,
      }),
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})[Tt]?(\d{2})?(\d{2})?(\d{2})?',
    ).firstMatch(value);
    if (match == null) return null;

    try {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.tryParse(match.group(4) ?? '') ?? 0,
        int.tryParse(match.group(5) ?? '') ?? 0,
        int.tryParse(match.group(6) ?? '') ?? 0,
      );
    } on FormatException {
      return null;
    }
  }

  BigInt? _parseAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;

    final major = BigInt.parse(match.group(1)!);
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    final minor = fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction);
    return major * BigInt.from(100) + minor;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return null;
  }
}

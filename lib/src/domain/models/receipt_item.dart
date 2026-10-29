import 'dart:convert';

final class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.lineTotalMinor,
    required this.source,
    this.unitPriceMinor,
    this.currencyCode,
    this.confidence,
  });

  final String name;
  final double quantity;
  final BigInt? unitPriceMinor;
  final BigInt? lineTotalMinor;
  final String? currencyCode;
  final String source;
  final double? confidence;

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit_price_minor': unitPriceMinor?.toString(),
    'line_total_minor': lineTotalMinor?.toString(),
    'currency': currencyCode,
    'source': source,
    'confidence': confidence,
  };

  static ReceiptItem? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = raw['name'];
    final quantity = raw['quantity'];
    final source = raw['source'];
    if (name is! String ||
        name.trim().isEmpty ||
        quantity is! num ||
        quantity <= 0 ||
        !quantity.toDouble().isFinite ||
        source is! String) {
      return null;
    }
    return ReceiptItem(
      name: name.trim(),
      quantity: quantity.toDouble(),
      unitPriceMinor: BigInt.tryParse('${raw['unit_price_minor'] ?? ''}'),
      lineTotalMinor: BigInt.tryParse('${raw['line_total_minor'] ?? ''}'),
      currencyCode: raw['currency'] is String
          ? raw['currency'] as String
          : null,
      source: source,
      confidence: raw['confidence'] is num
          ? (raw['confidence'] as num).toDouble()
          : null,
    );
  }
}

List<ReceiptItem> receiptItemsFromPayload(String payload) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      return const [];
    }
    return (decoded['items'] as List)
        .map(ReceiptItem.fromJson)
        .whereType<ReceiptItem>()
        .toList(growable: false);
  } on Object {
    return const [];
  }
}

String receiptPayloadWithItems(String payload, List<ReceiptItem> items) {
  Map<String, dynamic> decoded;
  try {
    final raw = jsonDecode(payload);
    decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  } on Object {
    decoded = <String, dynamic>{};
  }
  decoded['items'] = items.map((item) => item.toJson()).toList(growable: false);
  return jsonEncode(decoded);
}

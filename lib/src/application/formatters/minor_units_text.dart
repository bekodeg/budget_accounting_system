BigInt parseMinorUnitsText(String raw, {int fractionDigits = 2}) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return BigInt.zero;
  }

  final pattern = RegExp(r'^([+-]?)(\d+)(?:\.(\d*))?$');
  final match = pattern.firstMatch(normalized);
  if (match == null) {
    throw const FormatException('Invalid decimal amount.');
  }

  final sign = match.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
  final whole = BigInt.parse(match.group(2)!);
  final rawFraction = match.group(3) ?? '';
  if (rawFraction.length > fractionDigits) {
    throw FormatException(
      'Amount supports at most $fractionDigits fraction digits.',
    );
  }

  final scale = BigInt.from(10).pow(fractionDigits);
  final fraction = rawFraction
      .padRight(fractionDigits, '0')
      .substring(0, fractionDigits);
  final fractionValue = fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction);

  return sign * (whole * scale + fractionValue);
}

String formatMinorUnits(
  BigInt minorUnits, {
  int fractionDigits = 2,
}) {
  final negative = minorUnits.isNegative;
  final absolute = minorUnits.abs();
  final scale = BigInt.from(10).pow(fractionDigits);
  final whole = absolute ~/ scale;

  if (fractionDigits == 0) {
    return '${negative ? '-' : ''}$whole';
  }

  final fraction = (absolute % scale)
      .toString()
      .padLeft(fractionDigits, '0');
  return '${negative ? '-' : ''}$whole.$fraction';
}

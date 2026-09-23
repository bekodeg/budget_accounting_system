import '../errors/domain_validation_error.dart';

final class Currency {
  Currency._(this.code);

  factory Currency(String rawCode) {
    final normalized = rawCode.trim().toUpperCase();
    final isValid = RegExp(r'^[A-Z]{3}$').hasMatch(normalized);
    if (!isValid) {
      throw const DomainValidationError(
        code: DomainValidationCode.invalidCurrency,
        message: 'Currency must be a three-letter ISO-style code.',
      );
    }

    return Currency._(normalized);
  }

  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

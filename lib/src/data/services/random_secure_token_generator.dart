import 'dart:convert';
import 'dart:math';

import '../../application/ports/secure_token_generator.dart';

final class RandomSecureTokenGenerator implements SecureTokenGenerator {
  RandomSecureTokenGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextToken({int bytes = 32}) {
    if (bytes <= 0) {
      throw ArgumentError.value(bytes, 'bytes', 'Must be positive.');
    }
    final values = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64Url.encode(values);
  }
}

abstract interface class SecureTokenGenerator {
  String nextToken({int bytes = 32});
}

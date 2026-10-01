final class GeneratedIdentityKeyPair {
  const GeneratedIdentityKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  final String publicKey;
  final String privateKey;
}

abstract interface class IdentityKeyPairGenerator {
  Future<GeneratedIdentityKeyPair> generate();

  Future<String> publicKeyFromPrivate(String privateKey);
}

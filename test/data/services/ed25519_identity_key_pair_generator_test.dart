import 'package:budget_accounting_system/src/data/services/ed25519_identity_key_pair_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives the same public key from generated private seed', () async {
    final generator = Ed25519IdentityKeyPairGenerator();

    final pair = await generator.generate();
    final derived = await generator.publicKeyFromPrivate(pair.privateKey);

    expect(pair.publicKey, startsWith('ed25519:'));
    expect(derived, pair.publicKey);
    expect(pair.privateKey, isNotEmpty);
  });
}

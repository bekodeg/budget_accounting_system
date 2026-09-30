import '../ports/budget_transport_secret_store.dart';
import '../ports/secure_token_generator.dart';

final class BudgetTransportSecretManager {
  const BudgetTransportSecretManager({
    required BudgetTransportSecretStore store,
    required SecureTokenGenerator tokenGenerator,
  }) : _store = store,
       _tokenGenerator = tokenGenerator;

  final BudgetTransportSecretStore _store;
  final SecureTokenGenerator _tokenGenerator;

  Future<String> getOrCreate(String budgetId) async {
    final existing = await _store.load(budgetId);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _tokenGenerator.nextToken(bytes: 32);
    await _store.save(budgetId: budgetId, secret: generated);
    return generated;
  }

  Future<void> import({
    required String budgetId,
    required String secret,
  }) async {
    final existing = await _store.load(budgetId);
    if (existing != null && existing.isNotEmpty && existing != secret) {
      throw StateError('Transport secret conflicts with local budget secret.');
    }
    if (existing == null || existing.isEmpty) {
      await _store.save(budgetId: budgetId, secret: secret);
    }
  }

  Future<String> require(String budgetId) async {
    final secret = await _store.load(budgetId);
    if (secret == null || secret.isEmpty) {
      throw StateError('Transport secret is unavailable for budget $budgetId.');
    }
    return secret;
  }
}

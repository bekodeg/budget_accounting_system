import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'budget_transport_secret_manager.dart';

final class LanDiscoveryTokenService {
  LanDiscoveryTokenService({
    required BudgetTransportSecretManager transportSecretManager,
    Hmac? hmac,
  }) : _transportSecretManager = transportSecretManager,
       _hmac = hmac ?? Hmac.sha256();

  final BudgetTransportSecretManager _transportSecretManager;
  final Hmac _hmac;

  Future<String> forBudget(String budgetId) async {
    final secret = await _transportSecretManager.require(budgetId);
    final mac = await _hmac.calculateMac(
      utf8.encode('budget-lan-discovery-v1'),
      secretKey: SecretKey(base64Url.decode(secret)),
    );
    return base64Url
        .encode(mac.bytes.take(12).toList(growable: false))
        .replaceAll('=', '');
  }
}

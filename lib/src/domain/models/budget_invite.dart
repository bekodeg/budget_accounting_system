import 'domain_types.dart';

final class InviteCryptoParameters {
  const InviteCryptoParameters({
    required this.signatureAlgorithm,
    required this.kdf,
    required this.transportCipher,
    required this.salt,
    required this.bootstrapSecret,
  });

  final String signatureAlgorithm;
  final String kdf;
  final String transportCipher;
  final String salt;
  final String bootstrapSecret;
}

final class BudgetInvite {
  const BudgetInvite({
    required this.version,
    required this.inviteId,
    required this.budgetId,
    required this.budgetName,
    required this.baseCurrency,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerDeviceId,
    required this.ownerPublicKey,
    required this.role,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    required this.crypto,
    required this.signature,
  });

  static const currentVersion = 1;

  final int version;
  final String inviteId;
  final String budgetId;
  final String budgetName;
  final String baseCurrency;
  final String ownerUserId;
  final String ownerName;
  final String ownerDeviceId;
  final String ownerPublicKey;
  final MemberRole role;
  final String nonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final InviteCryptoParameters crypto;
  final String signature;

  BudgetInvite withSignature(String value) {
    return BudgetInvite(
      version: version,
      inviteId: inviteId,
      budgetId: budgetId,
      budgetName: budgetName,
      baseCurrency: baseCurrency,
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      ownerDeviceId: ownerDeviceId,
      ownerPublicKey: ownerPublicKey,
      role: role,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      crypto: crypto,
      signature: value,
    );
  }
}

final class BudgetInvitePreview {
  const BudgetInvitePreview({required this.invite, required this.rawPayload});

  final BudgetInvite invite;
  final String rawPayload;
}

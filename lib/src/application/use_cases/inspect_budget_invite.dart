import '../../domain/models/budget_invite.dart';
import '../errors/invite_error.dart';
import '../ports/identity_signature_service.dart';
import '../ports/invite_consumption_store.dart';
import '../services/budget_invite_codec.dart';

final class InspectBudgetInvite {
  InspectBudgetInvite({
    required IdentitySignatureService signatureService,
    required InviteConsumptionStore consumptionStore,
    BudgetInviteCodec codec = const BudgetInviteCodec(),
    DateTime Function()? now,
  }) : _signatureService = signatureService,
       _consumptionStore = consumptionStore,
       _codec = codec,
       _now = now ?? _utcNow;

  final IdentitySignatureService _signatureService;
  final InviteConsumptionStore _consumptionStore;
  final BudgetInviteCodec _codec;
  final DateTime Function() _now;

  Future<BudgetInvitePreview> call(String rawPayload) async {
    final invite = _codec.decode(rawPayload);

    if (invite.crypto.signatureAlgorithm != 'ed25519' ||
        invite.crypto.kdf != 'hkdf-sha256' ||
        invite.crypto.transportCipher != 'chacha20-poly1305') {
      throw const InviteError(
        InviteErrorCode.invalidFormat,
        'Криптографические параметры приглашения не поддерживаются.',
      );
    }

    if (!_now().toUtc().isBefore(invite.expiresAt)) {
      throw const InviteError(
        InviteErrorCode.expired,
        'Срок действия приглашения истёк.',
      );
    }

    if (await _consumptionStore.isConsumed(invite.inviteId)) {
      throw const InviteError(
        InviteErrorCode.alreadyConsumed,
        'Это приглашение уже использовано на устройстве.',
      );
    }

    final valid = await _signatureService.verify(
      publicKey: invite.ownerPublicKey,
      message: _codec.unsignedBytes(invite),
      signature: invite.signature,
    );
    if (!valid) {
      throw const InviteError(
        InviteErrorCode.invalidSignature,
        'Подпись приглашения недействительна.',
      );
    }

    return BudgetInvitePreview(invite: invite, rawPayload: rawPayload);
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

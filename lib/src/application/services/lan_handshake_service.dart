import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/lan_peer_hello.dart';
import '../../domain/models/lan_session.dart';
import '../../domain/models/public_identity.dart';
import '../errors/lan_session_error.dart';
import '../ports/identity_signature_service.dart';
import '../ports/secure_token_generator.dart';
import 'budget_transport_secret_manager.dart';
import 'lan_peer_hello_codec.dart';

final class LanHandshakeService {
  LanHandshakeService({
    required BudgetTransportSecretManager transportSecretManager,
    required IdentitySignatureService signatureService,
    required SecureTokenGenerator tokenGenerator,
    Hmac? hmac,
    LanPeerHelloCodec codec = const LanPeerHelloCodec(),
  }) : _transportSecretManager = transportSecretManager,
       _signatureService = signatureService,
       _tokenGenerator = tokenGenerator,
       _hmac = hmac ?? Hmac.sha256(),
       _codec = codec;

  final BudgetTransportSecretManager _transportSecretManager;
  final IdentitySignatureService _signatureService;
  final SecureTokenGenerator _tokenGenerator;
  final Hmac _hmac;
  final LanPeerHelloCodec _codec;

  Future<LanPeerHello> create({
    required String budgetId,
    required PublicIdentity identity,
  }) async {
    final peer = LanPeerDescriptor(
      budgetId: budgetId,
      userId: identity.userId,
      deviceId: identity.deviceId,
      publicKey: identity.publicKey,
      nonce: _tokenGenerator.nextToken(bytes: 24),
    );
    final secret = await _transportSecretManager.require(budgetId);
    final proof = await _secretProof(secret: secret, peer: peer);
    final signature = await _signatureService.sign(
      deviceId: identity.deviceId,
      message: _codec.signatureBytes(peer: peer, secretProof: proof),
    );

    return LanPeerHello(
      version: LanPeerHello.currentVersion,
      peer: peer,
      secretProof: proof,
      identitySignature: signature,
    );
  }

  Future<void> verify({
    required String expectedBudgetId,
    required LanPeerHello hello,
  }) async {
    if (hello.peer.budgetId != expectedBudgetId) {
      throw const LanSessionError(
        LanSessionErrorCode.budgetMismatch,
        'Peer belongs to another budget.',
      );
    }

    final secret = await _transportSecretManager.require(expectedBudgetId);
    final expectedProof = await _secretProof(
      secret: secret,
      peer: hello.peer,
    );
    if (!_constantTimeEquals(
      base64Url.decode(expectedProof),
      base64Url.decode(hello.secretProof),
    )) {
      throw const LanSessionError(
        LanSessionErrorCode.invalidSecretProof,
        'Peer does not know the budget transport secret.',
      );
    }

    final identityValid = await _signatureService.verify(
      publicKey: hello.peer.publicKey,
      message: _codec.signatureBytes(
        peer: hello.peer,
        secretProof: hello.secretProof,
      ),
      signature: hello.identitySignature,
    );
    if (!identityValid) {
      throw const LanSessionError(
        LanSessionErrorCode.invalidIdentitySignature,
        'Peer identity signature is invalid.',
      );
    }
  }

  Future<String> _secretProof({
    required String secret,
    required LanPeerDescriptor peer,
  }) async {
    final mac = await _hmac.calculateMac(
      _codec.descriptorBytes(peer),
      secretKey: SecretKey(base64Url.decode(secret)),
    );
    return base64Url.encode(mac.bytes);
  }
}

bool _constantTimeEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

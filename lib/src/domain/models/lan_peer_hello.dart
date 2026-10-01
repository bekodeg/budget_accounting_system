import 'lan_session.dart';

final class LanPeerHello {
  const LanPeerHello({
    required this.version,
    required this.peer,
    required this.secretProof,
    required this.identitySignature,
  });

  static const currentVersion = 1;

  final int version;
  final LanPeerDescriptor peer;
  final String secretProof;
  final String identitySignature;
}

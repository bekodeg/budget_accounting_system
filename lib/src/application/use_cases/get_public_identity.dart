import '../../domain/models/public_identity.dart';
import 'ensure_local_identity.dart';

final class GetPublicIdentity {
  const GetPublicIdentity(this._ensureLocalIdentity);

  final EnsureLocalIdentity _ensureLocalIdentity;

  Future<PublicIdentity> call(String userId) {
    return _ensureLocalIdentity(userId);
  }
}

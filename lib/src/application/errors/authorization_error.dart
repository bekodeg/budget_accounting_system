enum AuthorizationErrorCode { unauthenticated, notMember, forbidden, lastOwner }

final class AuthorizationError implements Exception {
  const AuthorizationError({required this.code, required this.message});

  final AuthorizationErrorCode code;
  final String message;

  @override
  String toString() => 'AuthorizationError($code): $message';
}

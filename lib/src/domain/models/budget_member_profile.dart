import 'domain_types.dart';

final class BudgetMemberProfile {
  const BudgetMemberProfile({
    required this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
    required this.revokedAt,
  });

  final String userId;
  final String name;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  BudgetMemberProfile copyWith({MemberRole? role, DateTime? revokedAt}) {
    return BudgetMemberProfile(
      userId: userId,
      name: name,
      role: role ?? this.role,
      joinedAt: joinedAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }
}

final class AppSession {
  const AppSession({
    required this.userId,
    required this.budgetId,
  });

  final String userId;
  final String budgetId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSession &&
          other.userId == userId &&
          other.budgetId == budgetId;

  @override
  int get hashCode => Object.hash(userId, budgetId);
}
